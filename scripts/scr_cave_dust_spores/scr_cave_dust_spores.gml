/// @description Camera view bounds for ambient cave dust/spores.
/// @returns {Struct}
function scr_cave_dust_get_view() {
    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    return {
        x: camera_get_view_x(_cam),
        y: camera_get_view_y(_cam),
        w: camera_get_view_width(_cam),
        h: camera_get_view_height(_cam)
    };
}

/// @description One dust/spore mote at a random position inside the view (optional padding).
/// @param {Real} [_vx]
/// @param {Real} [_vy]
/// @param {Real} [_vw]
/// @param {Real} [_vh]
/// @returns {Struct}
function scr_cave_dust_spawn_one(_vx, _vy, _vw, _vh) {
    if (_vx == undefined) {
        var _view = scr_cave_dust_get_view();
        _vx = _view.x;
        _vy = _view.y;
        _vw = _view.w;
        _vh = _view.h;
    }

    var _pad = BULB_CAVE_DUST_SPAWN_PAD;
    var _life = irandom_range(BULB_CAVE_DUST_LIFE_MIN, BULB_CAVE_DUST_LIFE_MAX);

    return {
        x: _vx + random(_vw) + random_range(-_pad, _pad),
        y: _vy + random(_vh) + random_range(-_pad, _pad),
        vx: random_range(-BULB_CAVE_DUST_DRIFT, BULB_CAVE_DUST_DRIFT),
        vy: random_range(-BULB_CAVE_DUST_DRIFT, BULB_CAVE_DUST_DRIFT),
        life: _life,
        max_life: _life,
        size: choose(1, 1, 1, 2),
        phase: random(360),
        wobble: 0.012 + random(0.018)
    };
}

/// @description Init ambient dust pool on obj_bulb_controller.
/// @param {Id.Instance} _controller
function scr_cave_dust_init(_controller) {
    with (_controller) {
        cave_dust_list = [];
        var _view = scr_cave_dust_get_view();
        var _count = scr_cave_dust_target_count(_view.w, _view.h);

        for (var _i = 0; _i < _count; _i++) {
            array_push(cave_dust_list, scr_cave_dust_spawn_one(_view.x, _view.y, _view.w, _view.h));
        }
    }
}

/// @description Particle count scales slightly with viewport area.
/// @param {Real} _vw
/// @param {Real} _vh
/// @returns {Real}
function scr_cave_dust_target_count(_vw, _vh) {
    var _count = floor((_vw * _vh) / BULB_CAVE_DUST_AREA_DIV);
    return clamp(_count, BULB_CAVE_DUST_COUNT_MIN, BULB_CAVE_DUST_COUNT_MAX);
}

/// @description Drift motes within the camera view; respawn when they leave or expire.
/// @param {Id.Instance} _controller obj_bulb_controller
function scr_cave_dust_step(_controller) {
    if (!BULB_CAVE_DUST_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "cave_dust_list")) {
            scr_cave_dust_init(_controller);
        }

        var _view = scr_cave_dust_get_view();
        var _target = scr_cave_dust_target_count(_view.w, _view.h);
        var _margin = BULB_CAVE_DUST_CULL_MARGIN;

        while (array_length(cave_dust_list) < _target) {
            array_push(cave_dust_list, scr_cave_dust_spawn_one(_view.x, _view.y, _view.w, _view.h));
        }

        while (array_length(cave_dust_list) > _target) {
            array_delete(cave_dust_list, array_length(cave_dust_list) - 1, 1);
        }

        for (var _i = array_length(cave_dust_list) - 1; _i >= 0; _i--) {
            var _p = cave_dust_list[_i];
            _p.phase += _p.wobble;
            _p.x += _p.vx + lengthdir_x(BULB_CAVE_DUST_WOBBLE, _p.phase) * 0.07;
            _p.y += _p.vy + lengthdir_y(BULB_CAVE_DUST_WOBBLE, _p.phase) * 0.05;
            _p.life -= 1;

            var _outside = (_p.x < _view.x - _margin || _p.x > _view.x + _view.w + _margin ||
                _p.y < _view.y - _margin || _p.y > _view.y + _view.h + _margin ||
                _p.life <= 0);

            if (_outside) {
                cave_dust_list[_i] = scr_cave_dust_spawn_one(_view.x, _view.y, _view.w, _view.h);
            } else {
                cave_dust_list[_i] = _p;
            }
        }
    }
}

/// @description Draw soft dust/spores across the lit cave (before emissive glow).
/// @param {Id.Instance} _controller obj_bulb_controller
function scr_cave_dust_draw(_controller) {
    if (!BULB_CAVE_DUST_ENABLED) return;

    with (_controller) {
        if (!variable_instance_exists(id, "cave_dust_list")) return;

        var _view = scr_cave_dust_get_view();
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
        draw_set_color(make_colour_rgb(BULB_CAVE_DUST_COL_R, BULB_CAVE_DUST_COL_G, BULB_CAVE_DUST_COL_B));

        for (var _i = 0; _i < array_length(cave_dust_list); _i++) {
            var _p = cave_dust_list[_i];

            if (_p.x < _view.x - 4 || _p.x > _view.x + _view.w + 4 ||
                _p.y < _view.y - 4 || _p.y > _view.y + _view.h + 4) {
                continue;
            }

            var _fade = _p.life / _p.max_life;
            var _a = BULB_CAVE_DUST_ALPHA * (0.35 + 0.65 * _fade);
            if (_a <= 0.01) continue;

            draw_set_alpha(_a);
            var _px = floor(_p.x);
            var _py = floor(_p.y);

            if (_p.size >= 2) {
                draw_rectangle(_px - 1, _py - 1, _px, _py, false);
            } else {
                draw_rectangle(_px, _py, _px, _py, false);
            }
        }

        gpu_set_texfilter(_old_tex);
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}
