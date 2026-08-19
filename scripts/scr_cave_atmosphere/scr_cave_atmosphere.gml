/// @description Init cave fog scroll state on obj_bulb_controller.
/// @param {Id.Instance} _controller
function scr_cave_atmosphere_init(_controller) {
    with (_controller) {
        fog_scroll_x = 0;
        fog_layer_start_x = 0;
        fog_layer_id = layer_get_id(BULB_CAVE_FOG_LAYER);
    }
}

/// @description Remember fog tile layer origin (Room Start) and hide from normal draw if present.
/// @param {Id.Instance} _controller
function scr_cave_atmosphere_bind_fog_layer(_controller) {
    with (_controller) {
        fog_layer_id = layer_get_id(BULB_CAVE_FOG_LAYER);
        if (fog_layer_id == -1) return;

        fog_layer_start_x = layer_get_x(fog_layer_id);
        layer_set_visible(fog_layer_id, false);
    }
}

/// @description Drift fog horizontally (procedural wisps + optional fog tile layer).
/// @param {Id.Instance} _controller
function scr_cave_fog_step(_controller) {
    if (!BULB_CAVE_FOG_ENABLED) return;

    with (_controller) {
        fog_scroll_x += BULB_CAVE_FOG_DRIFT_SPEED;

        if (fog_layer_id != -1) {
            layer_x(fog_layer_id, fog_layer_start_x + fog_scroll_x * BULB_CAVE_FOG_LAYER_PARALLAX);
        }
    }
}

/// @description Draw low cave mist in front of parallax walls, behind the player redraw.
/// @param {Id.Instance} _controller
function scr_cave_fog_draw(_controller) {
    if (!BULB_CAVE_FOG_ENABLED) return;

    with (_controller) {
        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) {
            _cam = obj_camera_controller.cam;
        }

        camera_apply(_cam);

        var _vx = camera_get_view_x(_cam);
        var _vy = camera_get_view_y(_cam);
        var _vw = camera_get_view_width(_cam);
        var _vh = camera_get_view_height(_cam);

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        gpu_set_texfilter(false);
        gpu_set_blendmode(bm_normal);
        draw_set_color(make_colour_rgb(BULB_CAVE_FOG_COL_R, BULB_CAVE_FOG_COL_G, BULB_CAVE_FOG_COL_B));

        // Optional painted fog tilemap (hide layer in Room Editor — drawn here after lighting).
        if (fog_layer_id != -1) {
            var _tm = layer_tilemap_get_id(fog_layer_id);
            if (_tm != -1) {
                draw_set_alpha(BULB_CAVE_FOG_TILE_ALPHA);
                draw_tilemap(
                    _tm,
                    layer_get_x(fog_layer_id) + tilemap_get_x(_tm),
                    layer_get_y(fog_layer_id) + tilemap_get_y(_tm)
                );
            }
        }

        // Procedural horizontal mist bands (works with or without a fog tile layer).
        var _band_step = BULB_CAVE_FOG_BAND_SPACING;
        var _band_h = BULB_CAVE_FOG_BAND_HEIGHT;
        var _start_band = floor((_vy - _band_step) / _band_step);

        for (var _b = _start_band; _b < _start_band + ceil(_vh / _band_step) + 2; _b++) {
            var _by = _b * _band_step;
            var _phase = _b * 0.61 + fog_scroll_x * 0.004;
            var _alpha = BULB_CAVE_FOG_ALPHA * (0.55 + 0.45 * ((dsin(_phase) + 1) * 0.5));
            draw_set_alpha(_alpha);

            var _chunk_w = BULB_CAVE_FOG_CHUNK_W;
            var _x0 = floor((_vx - fog_scroll_x) / _chunk_w) * _chunk_w + fog_scroll_x - _chunk_w;

            for (var _sx = _x0; _sx < _vx + _vw + _chunk_w; _sx += _chunk_w * 0.85) {
                var _wobble = dsin(_sx * 0.015 + _phase) * 6;
                var _w = _chunk_w * (0.55 + 0.35 * ((dsin(_sx * 0.031 + _phase * 1.7) + 1) * 0.5));
                draw_rectangle(
                    floor(_sx),
                    floor(_by + _wobble),
                    floor(_sx + _w),
                    floor(_by + _band_h + _wobble),
                    false
                );
            }
        }

        gpu_set_texfilter(_old_tex);
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}

/// @description Soft dark screen-edge vignette (drawn after the player).
function scr_cave_vignette_draw() {
    if (!BULB_CAVE_VIGNETTE_ENABLED) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = camera_get_view_width(_cam);
    var _vh = camera_get_view_height(_cam);
    var _aspect = _vw / max(_vh, 1);

    static _u_strength = shader_get_uniform(shd_cave_vignette, "u_strength");
    static _u_softness = shader_get_uniform(shd_cave_vignette, "u_softness");
    static _u_aspect = shader_get_uniform(shd_cave_vignette, "u_aspect");

    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(true);
    gpu_set_blendmode(bm_normal);
    draw_set_color(c_white);
    draw_set_alpha(1);

    shader_set(shd_cave_vignette);
    shader_set_uniform_f(_u_strength, BULB_CAVE_VIGNETTE_STRENGTH);
    shader_set_uniform_f(_u_softness, BULB_CAVE_VIGNETTE_SOFTNESS);
    shader_set_uniform_f(_u_aspect, _aspect);
    draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
    shader_reset();

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

// ---------------------------------------------------------------------------------------
// Cave fairies — drifting motes that each own a BulbLight.
// ---------------------------------------------------------------------------------------

/// @description Init the fairy pool on obj_bulb_controller.
function scr_fairy_init(_controller) {
    with (_controller) {
        fairy_list = [];
    }
}

/// @description Collision tilemap used to keep fairies out of solid rock.
function scr_fairy_collision_tilemap() {
    var _l = layer_get_id("lay_collision");
    if (_l != -1) {
        var _tm = layer_tilemap_get_id(_l);
        if (_tm != -1 && _tm != noone) return _tm;
    }
    return -1;
}

/// @description True if the point is clear of rock. Blank tile index 0 counts as solid:
/// this room authors its floors as invisible collision cells, so testing for visible art
/// would let fairies sit inside the ground.
function scr_fairy_point_is_open(_tm, _x, _y) {
    if (_x < 12 || _y < 12 || _x > room_width - 12 || _y > room_height - 12) return false;
    if (_tm == -1) return true;
    return tile_get_empty(tilemap_get_at_pixel(_tm, floor(_x), floor(_y)));
}

/// @description One fairy plus its light. Light is undefined if Bulb isn't up yet.
function scr_fairy_make(_x, _y) {
    var _light = undefined;

    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _light = new BulbLight(global.bulb_renderer, BULB_FAIRY_LIGHT_SPRITE, 0, _x, _y);
        _light.blend = BULB_FAIRY_LIGHT_BLEND;
        _light.intensity = BULB_FAIRY_LIGHT_INTENSITY;
        _light.xscale = BULB_FAIRY_LIGHT_SCALE;
        _light.yscale = BULB_FAIRY_LIGHT_SCALE;
        _light.penumbraSize = 0;
        // Shadow casting is the expensive half of a dynamic light and these are tiny.
        _light.castShadows = false;
        _light.normalMap = true;
        _light.normalMapZ = BULB_FAIRY_LIGHT_NORMAL_MAP_Z;
    }

    return {
        x: _x,
        y: _y,
        ax: _x,
        ay: _y,
        tx: _x,
        ty: _y,
        vx: 0,
        vy: 0,
        retarget: irandom_range(BULB_FAIRY_RETARGET_MIN, BULB_FAIRY_RETARGET_MAX),
        phase: random(360),
        pulse_speed: BULB_FAIRY_PULSE_SPEED * random_range(0.75, 1.25),
        wing_phase: random(360),
        wing_speed: BULB_FAIRY_WING_SPEED * random_range(0.85, 1.15),
        light: _light
    };
}

/// @description Release every fairy light so they don't linger in Bulb's light array.
function scr_fairy_cleanup(_controller) {
    with (_controller) {
        if (!variable_instance_exists(id, "fairy_list")) return;

        for (var _i = 0; _i < array_length(fairy_list); _i++) {
            var _f = fairy_list[_i];
            if (_f.light != undefined) {
                _f.light.Destroy();
                _f.light = undefined;
            }
        }

        fairy_list = [];
    }
}

/// @description Populate the room with fairies: a dense cluster over each pond plus a
/// scatter through open space. Must run after scr_pond_bake so pond bounds exist.
function scr_fairy_spawn(_controller) {
    if (!BULB_FAIRY_ENABLED) return;

    scr_fairy_cleanup(_controller);

    with (_controller) {
        var _tm = scr_fairy_collision_tilemap();

        if (variable_instance_exists(id, "pond_list")) {
            for (var _i = 0; _i < array_length(pond_list); _i++) {
                var _b = scr_pond_draw_bounds(pond_list[_i]);

                for (var _n = 0; _n < BULB_FAIRY_POND_COUNT; _n++) {
                    if (array_length(fairy_list) >= BULB_FAIRY_MAX) break;

                    // Retry the hover height rather than the whole position, so the
                    // cluster stays spread across the water even under a low ceiling.
                    var _fx = _b.left + random(_b.w);
                    var _fy = undefined;
                    for (var _try = 0; _try < 6; _try++) {
                        var _cand = _b.top - random_range(BULB_FAIRY_POND_HOVER_MIN, BULB_FAIRY_POND_HOVER_MAX);
                        if (scr_fairy_point_is_open(_tm, _fx, _cand)) {
                            _fy = _cand;
                            break;
                        }
                    }
                    if (_fy == undefined) continue;

                    array_push(fairy_list, scr_fairy_make(_fx, _fy));
                }
            }
        }

        // Rejection sampling: most of a cave room is solid, so allow several tries each.
        var _placed = 0;
        var _tries = 0;
        var _max_tries = BULB_FAIRY_SPAWN_TRIES * BULB_FAIRY_ROOM_COUNT;

        while (_placed < BULB_FAIRY_ROOM_COUNT && _tries < _max_tries) {
            _tries += 1;
            if (array_length(fairy_list) >= BULB_FAIRY_MAX) break;

            var _rx = random(room_width);
            var _ry = random(room_height);
            if (!scr_fairy_point_is_open(_tm, _rx, _ry)) continue;

            array_push(fairy_list, scr_fairy_make(_rx, _ry));
            _placed += 1;
        }
    }
}

/// @description Drift fairies around their anchors and drive their light pulse.
function scr_fairy_step(_controller) {
    if (!BULB_FAIRY_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "fairy_list")) return;

        var _tm = scr_fairy_collision_tilemap();
        var _accel = BULB_FAIRY_ACCEL;
        var _drag = BULB_FAIRY_DRAG;
        var _vmax = BULB_FAIRY_SPEED_MAX;

        for (var _i = 0; _i < array_length(fairy_list); _i++) {
            var _f = fairy_list[_i];

            _f.retarget -= 1;
            if (_f.retarget <= 0) {
                _f.retarget = irandom_range(BULB_FAIRY_RETARGET_MIN, BULB_FAIRY_RETARGET_MAX);
                var _dir = random(360);
                var _dist = random(BULB_FAIRY_ROAM_RADIUS);
                var _cx = _f.ax + lengthdir_x(_dist, _dir);
                var _cy = _f.ay + lengthdir_y(_dist, _dir);
                if (scr_fairy_point_is_open(_tm, _cx, _cy)) {
                    _f.tx = _cx;
                    _f.ty = _cy;
                }
            }

            // Accelerate toward the target with drag, so it reads as flight rather than
            // sliding along a lerp.
            var _dx = _f.tx - _f.x;
            var _dy = _f.ty - _f.y;
            var _d = max(1, sqrt(_dx * _dx + _dy * _dy));
            _f.vx = clamp((_f.vx + (_dx / _d) * _accel) * _drag, -_vmax, _vmax);
            _f.vy = clamp((_f.vy + (_dy / _d) * _accel) * _drag, -_vmax, _vmax);

            var _nx = _f.x + _f.vx;
            var _ny = _f.y + _f.vy;
            if (scr_fairy_point_is_open(_tm, _nx, _ny)) {
                _f.x = _nx;
                _f.y = _ny;
            } else {
                _f.vx = -_f.vx * 0.5;
                _f.vy = -_f.vy * 0.5;
                _f.retarget = 0;
            }

            _f.phase += _f.pulse_speed;
            if (_f.phase >= 360) _f.phase -= 360;

            // Wings beat harder the faster the fairy is travelling.
            var _spd = sqrt(_f.vx * _f.vx + _f.vy * _f.vy);
            _f.wing_phase += _f.wing_speed * (1 + (_spd / max(_vmax, 0.01)) * BULB_FAIRY_WING_SPEED_GAIN);
            if (_f.wing_phase >= 360) _f.wing_phase -= 360;

            if (_f.light != undefined) {
                var _t = (dsin(_f.phase) + 1) * 0.5;
                var _mul = lerp(BULB_FAIRY_PULSE_MIN, BULB_FAIRY_PULSE_MAX, _t);
                _f.light.x = _f.x;
                _f.light.y = _f.y;
                _f.light.xscale = BULB_FAIRY_LIGHT_SCALE * _mul;
                _f.light.yscale = BULB_FAIRY_LIGHT_SCALE * _mul;
                _f.light.intensity = BULB_FAIRY_LIGHT_INTENSITY * _mul;
            }
        }
    }
}

/// @description Append one axis-aligned quad to an open pr_trianglelist.
/// Right and bottom are exclusive.
function scr_fairy_quad(_x0, _y0, _x1, _y1, _col, _alpha) {
    draw_vertex_colour(_x0, _y0, _col, _alpha);
    draw_vertex_colour(_x1, _y0, _col, _alpha);
    draw_vertex_colour(_x0, _y1, _col, _alpha);
    draw_vertex_colour(_x1, _y0, _col, _alpha);
    draw_vertex_colour(_x1, _y1, _col, _alpha);
    draw_vertex_colour(_x0, _y1, _col, _alpha);
}

/// @description Draw fairy bodies — a bright core with dimmer pixels either side. All of
/// them batch into one primitive.
function scr_fairy_draw(_controller) {
    if (!BULB_FAIRY_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "fairy_list")) return;
        var _n = array_length(fairy_list);
        if (_n <= 0) return;

        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;
        camera_apply(_cam);

        var _margin = BULB_FAIRY_CULL_MARGIN;
        var _vx0 = camera_get_view_x(_cam) - _margin;
        var _vy0 = camera_get_view_y(_cam) - _margin;
        var _vx1 = _vx0 + camera_get_view_width(_cam) + _margin * 2;
        var _vy1 = _vy0 + camera_get_view_height(_cam) + _margin * 2;

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        gpu_set_texfilter(false);
        gpu_set_blendmode(bm_normal);

        var _core = make_colour_rgb(BULB_FAIRY_CORE_R, BULB_FAIRY_CORE_G, BULB_FAIRY_CORE_B);
        var _wing = make_colour_rgb(BULB_FAIRY_WING_R, BULB_FAIRY_WING_G, BULB_FAIRY_WING_B);

        draw_primitive_begin(pr_trianglelist);
        for (var _i = 0; _i < _n; _i++) {
            var _f = fairy_list[_i];
            if (_f.x < _vx0 || _f.x > _vx1 || _f.y < _vy0 || _f.y > _vy1) continue;

            var _t = (dsin(_f.phase) + 1) * 0.5;
            var _a = BULB_FAIRY_BODY_ALPHA * lerp(0.7, 1, _t);
            var _px = floor(_f.x);
            var _py = floor(_f.y);

            scr_fairy_quad(_px, _py, _px + 2, _py + 2, _core, _a);

            // Wings sweep vertically and are widest, tallest and brightest at the ends of
            // the stroke, thinning out as they blur through the middle. Rounding the
            // offsets keeps every wing pixel on the pixel grid.
            var _flap = dsin(_f.wing_phase);
            var _spread = abs(_flap);
            var _wy = _py + round(-_flap * BULB_FAIRY_WING_RISE);
            var _ww = 1 + round(_spread * (BULB_FAIRY_WING_SPAN - 1));
            var _wh = (_spread > 0.75) ? 2 : 1;
            var _wa = _a * lerp(BULB_FAIRY_WING_ALPHA_MIN, BULB_FAIRY_WING_ALPHA_MAX, _spread);

            scr_fairy_quad(_px - _ww, _wy, _px, _wy + _wh, _wing, _wa);
            scr_fairy_quad(_px + 2, _wy, _px + 2 + _ww, _wy + _wh, _wing, _wa);
        }
        draw_primitive_end();

        gpu_set_texfilter(_old_tex);
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}
