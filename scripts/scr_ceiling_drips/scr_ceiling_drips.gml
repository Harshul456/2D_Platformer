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

/// @description Raycast down lay_collision for the first solid row under a drip.
/// @param {Real} _x
/// @param {Real} _y_start
/// @returns {Real|undefined}
function scr_ceiling_drip_find_floor_y(_x, _y_start) {
    if (global.tilemap_collision_id == noone) return undefined;

    var _limit = _y_start + BULB_CEILING_DRIP_MAX_FALL;
    var _px = floor(_x);

    for (var _y = _y_start; _y < _limit; _y += BULB_CEILING_DRIP_FLOOR_STEP) {
        if (check_tile_collision(_px, _y)) {
            return _y;
        }
    }

    return undefined;
}

/// @description Init drip lists on obj_bulb_controller.
/// @param {Id.Instance} _controller
function scr_ceiling_drip_init(_controller) {
    with (_controller) {
        drip_list = [];
        splash_list = [];
        drip_emitters = [];
    }
}

/// @description Spawn one falling drip pixel from an emitter.
/// @param {Struct} _emitter
/// @returns {Struct|undefined}
function scr_ceiling_drip_spawn_drop(_emitter) {
    if (_emitter.floor_y == undefined) {
        _emitter.floor_y = scr_ceiling_drip_find_floor_y(_emitter.x, _emitter.y + 4);
    }

    if (_emitter.floor_y == undefined) return undefined;

    return {
        x: _emitter.x + random_range(-BULB_CEILING_DRIP_X_JITTER, BULB_CEILING_DRIP_X_JITTER),
        y: _emitter.y,
        vy: BULB_CEILING_DRIP_FALL_SPEED + random_range(-0.25, 0.25),
        floor_y: _emitter.floor_y,
        color: choose(make_colour_rgb(155, 205, 235), c_white)
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

        var _view = scr_cave_dust_get_view();
        var _pad = BULB_CEILING_DRIP_VIEW_PAD;

        // Emitters — random intervals, only when near the camera.
        for (var _e = 0; _e < array_length(drip_emitters); _e++) {
            var _em = drip_emitters[_e];

            if (_em.x < _view.x - _pad || _em.x > _view.x + _view.w + _pad ||
                _em.y < _view.y - _pad || _em.y > _view.y + _view.h + _pad) {
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

        // Falling drips.
        for (var _i = array_length(drip_list) - 1; _i >= 0; _i--) {
            var _d = drip_list[_i];
            _d.y += _d.vy;

            if (_d.y >= _d.floor_y) {
                if (array_length(splash_list) < BULB_CEILING_DRIP_MAX_SPLASH) {
                    array_push(splash_list, scr_ceiling_drip_spawn_splash(_d.x, _d.floor_y, _d.color));
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
            var _d = drip_list[_i];
            draw_set_color(_d.color);
            draw_set_alpha(BULB_CEILING_DRIP_ALPHA);
            var _px = floor(_d.x);
            var _py = floor(_d.y);
            draw_rectangle(_px, _py, _px, _py, false);
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
