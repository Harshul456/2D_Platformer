/// @description Scan Tiles_Ceiling_Drips for stalactite drip spawn points.
/// @param {String} [_layer_name]
/// @returns {Array}
function scr_ceiling_drip_build_emitters(_layer_name = BULB_CEILING_DRIP_LAYER) {
    var _emitters = [];

    var _layer = layer_get_id(_layer_name);
    if (_layer == -1) return _emitters;

    var _tm = layer_tilemap_get_id(_layer);
    if (_tm == -1) return _emitters;

    var _tw = tilemap_get_tile_width(_tm);
    var _th = tilemap_get_tile_height(_tm);
    var _w = tilemap_get_width(_tm);
    var _h = tilemap_get_height(_tm);
    var _ox = layer_get_x(_layer) + tilemap_get_x(_tm);
    var _oy = layer_get_y(_layer) + tilemap_get_y(_tm);

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _data = tilemap_get(_tm, _cx, _cy);
            if (_data == -1 || tile_get_empty(_data)) continue;

            var _ex = _ox + _cx * _tw + _tw * 0.5;
            var _ey = _oy + _cy * _th + _th * BULB_CEILING_DRIP_SPAWN_Y_FRAC;

            array_push(_emitters, {
                x: _ex,
                y: _ey,
                timer: random(BULB_CEILING_DRIP_INTERVAL_MAX),
                interval: irandom_range(BULB_CEILING_DRIP_INTERVAL_MIN, BULB_CEILING_DRIP_INTERVAL_MAX),
                floor_y: undefined
            });
        }
    }

    return _emitters;
}

/// @description True if (_px,_py) is a drip landing surface (independent of player one-way shelf state).
/// Shelves 1/5/34/35/36/88/89 always catch across the full cell top so X jitter can't tunnel the lip.
/// @param {Id.TileMapElement} _tm
/// @param {Real} _px
/// @param {Real} _py
/// @returns {Bool}
function scr_ceiling_drip_point_is_floor(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var _td = tilemap_get_at_pixel(_tm, _px, _py);
    if (_td == 0) return false;

    var _idx = tile_get_index(_td);
    var _tw = tilemap_get_tile_width(_tm);
    var _th = tilemap_get_tile_height(_tm);
    var _tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
    var _tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var _cell_left = tilemap_get_x(_tm) + _tcx * _tw;
    var _cell_top = tilemap_get_y(_tm) + _tcy * _th;
    var _lx = _px - _cell_left;
    var _ly = _py - _cell_top;
    if (tile_get_mirror(_td)) _lx = _tw - 1 - _lx;
    if (tile_get_flip(_td)) _ly = _th - 1 - _ly;

    // One-way shelves / bridges — rain always lands on the top band (ignore player vsp / below-pass).
    if (tilecol_one_way_shelf_tile_index(_idx)) {
        if (tilemap_cell_above_is_solid(_tm, _px, _py)) return true; // buried cap = wall
        return (_ly >= 0 && _ly <= tilecol_one_way_shelf_max_ly(_idx));
    }

    var _sh = tilecol_shape_for_tile_index(_idx);
    return tilecol_solid_at_local(_sh, _lx, _ly, _tw, _th, _idx);
}

/// @description Raycast down for the first drip floor Y. Prefers pond surface over
/// collision ground so drips splash on water instead of falling through it.
/// Does NOT use check_tile_collision — player one-way shelf context (rising /
/// already-below) was making shelf hits intermittent.
/// @param {Real} _x
/// @param {Real} _y_start
/// @returns {Real|undefined}
function scr_ceiling_drip_find_floor_y(_x, _y_start) {
    var _limit = _y_start + BULB_CEILING_DRIP_MAX_FALL;
    var _px = floor(_x);

    // Pond surface (tile-23 water) — catch before ground so drips don't fall through.
    var _pond_y = undefined;
    if (BULB_POND_ENABLED) {
        _pond_y = scr_pond_surface_y_at(_px);
        if (_pond_y != undefined) {
            if (_pond_y <= _y_start + 1 || _pond_y > _limit) {
                _pond_y = undefined;
            }
        }
    }

    var _tm = (variable_global_exists("tilemap_collision_id") ? global.tilemap_collision_id : noone);
    var _floor_y = undefined;
    if (_tm != noone && _tm != -1) {
        var _step = max(1, BULB_CEILING_DRIP_FLOOR_STEP);

        // 1px-accurate scan through thin shelf caps (ly 0..3); step>1 only for empty air stretches.
        var _y = floor(_y_start);
        // Stop early if we've already passed a pond surface above the ground.
        var _scan_limit = _limit;
        if (_pond_y != undefined) _scan_limit = min(_scan_limit, _pond_y);

        while (_y < _scan_limit) {
            if (scr_ceiling_drip_point_is_floor(_tm, _px, _y)) {
                // Snap to the top of a shelf/full cell when we punched into the solid band.
                var _td = tilemap_get_at_pixel(_tm, _px, _y);
                if (_td != 0) {
                    var _idx = tile_get_index(_td);
                    var _th = tilemap_get_tile_height(_tm);
                    var _tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _y);
                    var _cell_top = tilemap_get_y(_tm) + _tcy * _th;
                    if (tilecol_one_way_shelf_tile_index(_idx) && !tilemap_cell_above_is_solid(_tm, _px, _y)) {
                        _floor_y = _cell_top;
                        break;
                    }
                }
                _floor_y = _y;
                break;
            }
            // Coarse step in open air; refine to 1px when a tile cell is nearby
            var _td_ahead = tilemap_get_at_pixel(_tm, _px, _y + _step);
            if (_td_ahead != 0 || tilemap_get_at_pixel(_tm, _px, _y + 1) != 0) {
                _y += 1;
            } else {
                _y += _step;
            }
        }
    }

    if (_pond_y != undefined && (_floor_y == undefined || _pond_y <= _floor_y)) {
        return _pond_y;
    }
    return _floor_y;
}

/// @description Init drip lists on obj_bulb_controller.
/// @param {Id.Instance} _controller
function scr_ceiling_drip_init(_controller) {
    with (_controller) {
        drip_list = [];
        splash_list = [];
        drip_emitters = [];
        drip_sfx_cooldown = 0;
        drip_sfx_last_clip = -1;
    }
}

/// @description Randomized drip splash SFX — when splash is in camera view (louder near player).
/// @param {Real} _x
/// @param {Real} _y
function scr_ceiling_drip_play_splash_sound(_x, _y) {
    if (!BULB_CEILING_DRIP_SFX_ENABLED) return;

    var _view = scr_cave_dust_get_view();
    var _pad = BULB_CEILING_DRIP_SFX_VIEW_PAD;
    if (_x < _view.x - _pad || _x > _view.x + _view.w + _pad ||
        _y < _view.y - _pad || _y > _view.y + _view.h + _pad) {
        return;
    }

    var _controller = instance_find(obj_bulb_controller, 0);
    if (_controller != noone) {
        with (_controller) {
            if (variable_instance_exists(id, "drip_sfx_cooldown") && drip_sfx_cooldown > 0) return;
        }
    }

    var _sounds = [snd_waterdrop_1, snd_waterdrop_2, snd_waterdrop_3];
    var _pick = irandom(array_length(_sounds) - 1);
    if (_controller != noone) {
        with (_controller) {
            if (variable_instance_exists(id, "drip_sfx_last_clip")
                && _pick == drip_sfx_last_clip && random(1) < 0.65) {
                _pick = (_pick + 1 + irandom(1)) mod array_length(_sounds);
            }
            drip_sfx_last_clip = _pick;
            drip_sfx_cooldown = BULB_CEILING_DRIP_SFX_COOLDOWN;
        }
    }

    // In view = audible; boost volume when the player is close to the splash.
    var _vol_t = BULB_CEILING_DRIP_SFX_VIEW_VOL;
    if (instance_exists(obj_player)) {
        var _hear_r = BULB_CEILING_DRIP_SFX_HEAR_RADIUS;
        var _dist = point_distance(_x, _y, obj_player.x, obj_player.y);
        if (_dist <= _hear_r) {
            _vol_t = max(_vol_t, (1 - (_dist / max(1, _hear_r))) * 0.72);
        }
    }

    // Skew pitch low — distant cave drips read deeper and softer.
    var _pitch_t = power(random(1), 1.35);
    var _pitch = lerp(BULB_CEILING_DRIP_SFX_PITCH_MIN, BULB_CEILING_DRIP_SFX_PITCH_MAX, _pitch_t)
        * BULB_CEILING_DRIP_SFX_PITCH_CAVE
        * random_range(1 - BULB_CEILING_DRIP_SFX_PITCH_JITTER, 1 + BULB_CEILING_DRIP_SFX_PITCH_JITTER);
    var _gain = lerp(BULB_CEILING_DRIP_SFX_VOL_MIN, BULB_CEILING_DRIP_SFX_VOL_MAX, _vol_t)
        * random_range(0.9, 1.02);

    var _snd_id = audio_play_sound(_sounds[_pick], BULB_CEILING_DRIP_SFX_AUDIO_PRIORITY, false);
    if (_snd_id != -1) {
        audio_sound_pitch(_snd_id, _pitch);
        audio_sound_gain(_snd_id, _gain, 0);
    }
}

/// @description Spawn one falling rain-streak drip from an emitter.
/// @param {Struct} _emitter
/// @returns {Struct|undefined}
function scr_ceiling_drip_spawn_drop(_emitter) {
    // Floor at the actual drop X — shared emitter.floor_y + X jitter could miss shelf lips.
    var _dx = _emitter.x + random_range(-BULB_CEILING_DRIP_X_JITTER, BULB_CEILING_DRIP_X_JITTER);
    var _floor_y = scr_ceiling_drip_find_floor_y(_dx, _emitter.y + 4);
    if (_floor_y == undefined) return undefined;

    var _vy = BULB_CEILING_DRIP_FALL_SPEED + random_range(-0.35, 0.55);
    var _len = clamp(round(_vy * BULB_CEILING_DRIP_STREAK_VY_MUL + random_range(-1, 2)),
        BULB_CEILING_DRIP_STREAK_MIN, BULB_CEILING_DRIP_STREAK_MAX);

    return {
        x: _dx,
        y: _emitter.y,
        vy: _vy,
        len: _len,
        floor_y: _floor_y,
        color: choose(make_colour_rgb(155, 205, 235), make_colour_rgb(190, 220, 245), c_white)
    };
}

/// @description Start a 2-frame splash when a drip hits the floor.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} _color
/// @returns {Struct}
function scr_ceiling_drip_spawn_splash(_x, _y, _color) {
    return {
        x: _x,
        y: _y,
        frame: 0,
        timer: 0,
        frame_len: BULB_CEILING_DRIP_SPLASH_FRAME_LEN,
        color: _color
    };
}

/// @description Simulate emitters, falling drips, and splashes.
/// @param {Id.Instance} _controller obj_bulb_controller
function scr_ceiling_drip_step(_controller) {
    if (!BULB_CEILING_DRIP_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "drip_list")) {
            scr_ceiling_drip_init(_controller);
        }

        if (!variable_instance_exists(id, "drip_emitters")) {
            drip_emitters = [];
        }

        if (variable_instance_exists(id, "drip_sfx_cooldown") && drip_sfx_cooldown > 0) {
            drip_sfx_cooldown--;
        }

        var _view = scr_cave_dust_get_view();
        var _pad = BULB_CEILING_DRIP_VIEW_PAD;

        // Emitters — keep raining from ceilings ABOVE the camera so streaks fall into view.
        // Skip only when horizontally off-column or already below the view.
        for (var _e = 0; _e < array_length(drip_emitters); _e++) {
            var _em = drip_emitters[_e];

            if (_em.x < _view.x - _pad || _em.x > _view.x + _view.w + _pad) {
                continue;
            }
            if (_em.y > _view.y + _view.h + _pad) {
                continue;
            }

            _em.timer -= 1;
            if (_em.timer > 0) {
                drip_emitters[_e] = _em;
                continue;
            }

            if (array_length(drip_list) < BULB_CEILING_DRIP_MAX_ACTIVE) {
                var _drop = scr_ceiling_drip_spawn_drop(_em);
                if (_drop != undefined) {
                    array_push(drip_list, _drop);
                }
            }

            _em.timer = _em.interval + irandom_range(-24, 24);
            _em.interval = irandom_range(BULB_CEILING_DRIP_INTERVAL_MIN, BULB_CEILING_DRIP_INTERVAL_MAX);
            drip_emitters[_e] = _em;
        }

        // Falling drips — slight accel so streaks read more like rain.
        var _tm_fall = (variable_global_exists("tilemap_collision_id") ? global.tilemap_collision_id : noone);
        for (var _i = array_length(drip_list) - 1; _i >= 0; _i--) {
            var _d = drip_list[_i];
            var _prev_y = _d.y;
            _d.vy = min(_d.vy + 0.045, BULB_CEILING_DRIP_FALL_SPEED + 2.4);
            _d.y += _d.vy;
            if (variable_struct_exists(_d, "len")) {
                _d.len = clamp(round(_d.vy * BULB_CEILING_DRIP_STREAK_VY_MUL),
                    BULB_CEILING_DRIP_STREAK_MIN, BULB_CEILING_DRIP_STREAK_MAX);
            }

            // Sweep the fall segment so fast drips can't skip a thin shelf band / pond surface.
            var _hit_y = undefined;
            if (_d.y >= _d.floor_y) {
                _hit_y = _d.floor_y;
            } else {
                // Live pond check — catches water even if floor was baked before ponds.
                if (BULB_POND_ENABLED) {
                    var _pond_hit = scr_pond_surface_y_at(floor(_d.x));
                    if (_pond_hit != undefined && _prev_y < _pond_hit && _d.y >= _pond_hit) {
                        _hit_y = _pond_hit;
                    }
                }
                if (_hit_y == undefined && _tm_fall != noone && _tm_fall != -1) {
                    var _px = floor(_d.x);
                    var _y0 = floor(_prev_y);
                    var _y1 = floor(_d.y);
                    for (var _sy = _y0; _sy <= _y1; _sy++) {
                        if (scr_ceiling_drip_point_is_floor(_tm_fall, _px, _sy)) {
                            var _td = tilemap_get_at_pixel(_tm_fall, _px, _sy);
                            if (_td != 0 && tilecol_one_way_shelf_tile_index(tile_get_index(_td))
                                && !tilemap_cell_above_is_solid(_tm_fall, _px, _sy)) {
                                var _th = tilemap_get_tile_height(_tm_fall);
                                var _tcy = tilemap_get_cell_y_at_pixel(_tm_fall, _px, _sy);
                                _hit_y = tilemap_get_y(_tm_fall) + _tcy * _th;
                            } else {
                                _hit_y = _sy;
                            }
                            break;
                        }
                    }
                }
            }

            if (_hit_y != undefined) {
                scr_ceiling_drip_play_splash_sound(_d.x, _hit_y);
                if (array_length(splash_list) < BULB_CEILING_DRIP_MAX_SPLASH) {
                    array_push(splash_list, scr_ceiling_drip_spawn_splash(_d.x, _hit_y, _d.color));
                }
                array_delete(drip_list, _i, 1);
            } else {
                drip_list[_i] = _d;
            }
        }

        // Splash animation (2 frames).
        for (var _s = array_length(splash_list) - 1; _s >= 0; _s--) {
            var _sp = splash_list[_s];
            _sp.timer += 1;

            if (_sp.timer >= _sp.frame_len) {
                _sp.timer = 0;
                _sp.frame += 1;
            }

            if (_sp.frame >= 2) {
                array_delete(splash_list, _s, 1);
            } else {
                splash_list[_s] = _sp;
            }
        }
    }
}

/// @description Draw one 2-frame splash (tiny blue/white pixel spread).
/// @param {Struct} _splash
function scr_ceiling_drip_draw_splash(_splash) {
    var _px = floor(_splash.x);
    var _py = floor(_splash.y);
    var _fade = 1 - (_splash.frame * 0.38 + _splash.timer / (_splash.frame_len * 2) * 0.2);
    var _a = BULB_CEILING_DRIP_SPLASH_ALPHA * clamp(_fade, 0.2, 1);

    draw_set_color(_splash.color);
    draw_set_alpha(_a);

    if (_splash.frame == 0) {
        draw_rectangle(_px - 1, _py, _px + 1, _py, false);
        draw_rectangle(_px, _py - 1, _px, _py - 1, false);
    } else {
        draw_rectangle(_px - 2, _py, _px + 2, _py, false);
        draw_rectangle(_px - 1, _py - 1, _px + 1, _py - 1, false);
    }
}

/// @description Draw one falling drip as a vertical rain streak (soft trail + bright tip).
/// @param {Struct} _drip
function scr_ceiling_drip_draw_drop(_drip) {
    var _px = floor(_drip.x);
    var _py = floor(_drip.y);
    var _len = (variable_struct_exists(_drip, "len") ? _drip.len : BULB_CEILING_DRIP_STREAK_MIN);
    _len = clamp(_len, BULB_CEILING_DRIP_STREAK_MIN, BULB_CEILING_DRIP_STREAK_MAX);

    // Clip streak so it doesn't poke through the floor on the impact frame.
    var _y2 = _py;
    if (variable_struct_exists(_drip, "floor_y")) {
        _y2 = min(_py, floor(_drip.floor_y) - 1);
    }
    var _y1 = max(_y2 - _len, _y2 - BULB_CEILING_DRIP_STREAK_MAX);
    if (_y2 < _y1) return;

    draw_set_color(_drip.color);

    // Soft trailing body (fades toward the top)
    var _body = max(1, _y2 - _y1 - 1);
    draw_set_alpha(BULB_CEILING_DRIP_ALPHA * 0.35);
    draw_rectangle(_px, _y1, _px, _y1 + max(1, floor(_body * 0.45)), false);
    draw_set_alpha(BULB_CEILING_DRIP_ALPHA * 0.65);
    draw_rectangle(_px, _y1 + max(0, floor(_body * 0.35)), _px, _y2 - 1, false);

    // Bright leading tip — the “raindrop head”
    draw_set_alpha(BULB_CEILING_DRIP_TIP_ALPHA);
    draw_rectangle(_px, _y2, _px, _y2, false);
}

/// @description Draw falling drips and floor splashes.
/// @param {Id.Instance} _controller obj_bulb_controller
function scr_ceiling_drip_draw(_controller) {
    if (!BULB_CEILING_DRIP_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "drip_list")) return;

        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) {
            _cam = obj_camera_controller.cam;
        }

        camera_apply(_cam);

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        gpu_set_texfilter(false);
        gpu_set_blendmode(bm_normal);

        for (var _i = 0; _i < array_length(drip_list); _i++) {
            scr_ceiling_drip_draw_drop(drip_list[_i]);
        }

        for (var _s = 0; _s < array_length(splash_list); _s++) {
            scr_ceiling_drip_draw_splash(splash_list[_s]);
        }

        gpu_set_texfilter(_old_tex);
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}

/// @description Bake drip emitters from the ceiling tile layer (Room Start).
/// @param {Id.Instance} _controller obj_bulb_controller
/// @param {String} [_layer_name]
function scr_ceiling_drip_bake_emitters(_controller, _layer_name = BULB_CEILING_DRIP_LAYER) {
    with (_controller) {
        drip_emitters = scr_ceiling_drip_build_emitters(_layer_name);
    }
}
