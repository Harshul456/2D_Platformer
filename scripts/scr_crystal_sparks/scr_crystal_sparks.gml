/// @description Init sparkle pool on a crystal light instance.
/// @param {Id.Instance} _inst obj_bulb_crystal_light
function scr_crystal_spark_init(_inst) {
    with (_inst) {
        spark_list = [];
        spark_spawn_accum = random(1);
    }
}

/// @description Spawn one white sparkle that orbits near the crystal.
/// @param {Real} _cx
/// @param {Real} _cy
/// @returns {Struct}
function scr_crystal_spark_create(_cx, _cy) {
    var _life = irandom_range(BULB_CRYSTAL_SPARK_LIFE_MIN, BULB_CRYSTAL_SPARK_LIFE_MAX);
    var _dir = choose(-1, 1);

    return {
        angle: random(360),
        radius: random_range(BULB_CRYSTAL_SPARK_ORBIT_R_MIN, BULB_CRYSTAL_SPARK_ORBIT_R_MAX),
        orbit_speed: random_range(BULB_CRYSTAL_SPARK_ORBIT_SPEED_MIN, BULB_CRYSTAL_SPARK_ORBIT_SPEED_MAX) * _dir,
        wobble_phase: random(360),
        wobble_amp: random_range(0.4, BULB_CRYSTAL_SPARK_WOBBLE),
        twinkle_phase: random(360),
        cx: _cx,
        cy: _cy,
        life: _life,
        max_life: _life,
        size: choose(1, 1, 1)
    };
}

/// @description Simulate sparkles orbiting / shimmering around each crystal.
/// @param {Id.Instance} _inst obj_bulb_crystal_light
function scr_crystal_spark_step(_inst) {
    if (!BULB_CRYSTAL_SPARKS_ENABLED) return;

    with (_inst) {
        if (!variable_instance_exists(id, "spark_list")) {
            scr_crystal_spark_init(_inst);
        }

        var _pulse = variable_instance_exists(id, "glow_pulse_t") ? glow_pulse_t : 0.5;
        var _cx = x;
        var _cy = y + BULB_CRYSTAL_SPARK_CENTER_Y;

        var _i = array_length(spark_list) - 1;
        while (_i >= 0) {
            var _p = spark_list[_i];
            _p.life -= 1;
            _p.cx = _cx;
            _p.cy = _cy;
            _p.angle += _p.orbit_speed;
            _p.wobble_phase += 0.05;
            _p.twinkle_phase += 0.11;

            var _r = _p.radius + dsin(_p.wobble_phase) * _p.wobble_amp;
            _p.x = _p.cx + lengthdir_x(_r, _p.angle);
            _p.y = _p.cy + lengthdir_y(_r, _p.angle) * 0.72;

            if (_p.life <= 0) {
                array_delete(spark_list, _i, 1);
            } else {
                spark_list[_i] = _p;
            }

            _i -= 1;
        }

        if (array_length(spark_list) >= BULB_CRYSTAL_SPARK_MAX) exit;

        var _spawn_rate = lerp(BULB_CRYSTAL_SPARK_RATE_MIN, BULB_CRYSTAL_SPARK_RATE_MAX, _pulse);
        spark_spawn_accum += _spawn_rate;

        while (spark_spawn_accum >= 1 && array_length(spark_list) < BULB_CRYSTAL_SPARK_MAX) {
            spark_spawn_accum -= 1;
            array_push(spark_list, scr_crystal_spark_create(_cx, _cy));
        }
    }
}

/// @description Draw soft white sparkles additively around crystals.
function scr_crystal_spark_draw_all() {
    if (!BULB_CRYSTAL_SPARKS_ENABLED) return;

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
    gpu_set_blendmode(bm_add);
    draw_set_color(c_white);

    with (obj_bulb_crystal_light) {
        if (!variable_instance_exists(id, "spark_list")) continue;

        var _pulse = variable_instance_exists(id, "glow_pulse_alpha") ? glow_pulse_alpha : 1;

        for (var _i = 0; _i < array_length(spark_list); _i++) {
            var _p = spark_list[_i];
            var _life_t = _p.life / _p.max_life;
            var _fade_in = min(1, (1 - _life_t) * 6);
            var _fade_out = min(1, _life_t * 3);
            var _twinkle = 0.45 + 0.55 * ((dsin(_p.twinkle_phase) + 1) * 0.5);
            var _a = _fade_in * _fade_out * _pulse * _twinkle * BULB_CRYSTAL_SPARK_ALPHA;
            if (_a <= 0.01) continue;

            draw_set_alpha(_a);
            var _px = floor(_p.x);
            var _py = floor(_p.y);
            draw_rectangle(_px, _py, _px, _py, false);
        }
    }

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}
