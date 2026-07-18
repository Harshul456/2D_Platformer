/// Screen-space distortion shockwaves. A ripple warps the composited scene outward
/// (water/heat refraction) — no color, just UV displacement. Applied to the lit-scene blit.

/// @function scr_hit_distort_ensure
function scr_hit_distort_ensure() {
    if (!variable_global_exists("hit_distort") || !is_array(global.hit_distort)) {
        global.hit_distort = [];
    }
}

/// @function scr_hit_distort_add
/// @description Spawn a distortion ripple at a room position.
/// @param {Real} _x Room X (center of the wave)
/// @param {Real} _y Room Y
/// @param {Real} [_strength] Size/intensity multiplier (finishers pass more)
function scr_hit_distort_add(_x, _y, _strength = 1) {
    if (!HIT_DISTORT_ENABLED) return;
    scr_hit_distort_ensure();

    // Cap concurrent ripples; drop the oldest so the shader array never overflows.
    if (array_length(global.hit_distort) >= HIT_DISTORT_MAX) {
        array_delete(global.hit_distort, 0, 1);
    }

    array_push(global.hit_distort, {
        x: _x,
        y: _y,
        age: 0,
        strength: _strength
    });
}

/// @function scr_hit_distort_step
/// @description Age ripples and retire expired ones. Call once per frame.
function scr_hit_distort_step() {
    if (!variable_global_exists("hit_distort") || !is_array(global.hit_distort)) return;

    for (var _i = array_length(global.hit_distort) - 1; _i >= 0; _i--) {
        var _r = global.hit_distort[_i];
        _r.age += 1;
        if (_r.age >= HIT_DISTORT_LIFE) {
            array_delete(global.hit_distort, _i, 1);
        }
    }
}

/// @function scr_hit_distort_shader_begin
/// @description If ripples are active, set sh_hit_distort with per-ripple uniforms.
/// @param {Id.Camera} _cam Camera used for the lit-scene blit (room->UV mapping)
/// @returns {Bool} true if the shader was set (caller must shader_reset afterwards)
function scr_hit_distort_shader_begin(_cam) {
    if (!HIT_DISTORT_ENABLED) return false;
    if (!variable_global_exists("hit_distort") || !is_array(global.hit_distort)) return false;

    var _n = array_length(global.hit_distort);
    if (_n <= 0) return false;
    _n = min(_n, HIT_DISTORT_MAX);

    var _cx = camera_get_view_x(_cam);
    var _cy = camera_get_view_y(_cam);
    var _cw = camera_get_view_width(_cam);
    var _ch = camera_get_view_height(_cam);
    if (_cw <= 0 || _ch <= 0) return false;

    var _centers   = array_create(_n * 2, 0);
    var _radii     = array_create(_n, 0);
    var _widths    = array_create(_n, 0);
    var _strengths = array_create(_n, 0);

    for (var _i = 0; _i < _n; _i++) {
        var _r = global.hit_distort[_i];
        var _t = clamp(_r.age / HIT_DISTORT_LIFE, 0, 1);

        // Center in UV (0..1) across the view.
        _centers[_i * 2]     = (_r.x - _cx) / _cw;
        _centers[_i * 2 + 1] = (_r.y - _cy) / _ch;

        // Ease-out expansion; strength decays as the wave spreads/thins.
        var _ease = 1 - power(1 - _t, 2);
        _radii[_i]     = lerp(HIT_DISTORT_R0, HIT_DISTORT_RMAX * (0.8 + 0.4 * _r.strength), _ease);
        _widths[_i]    = HIT_DISTORT_WIDTH;
        _strengths[_i] = HIT_DISTORT_STRENGTH * _r.strength * power(1 - _t, 1.3);
    }

    var _sh = sh_hit_distort;
    shader_set(_sh);
    shader_set_uniform_i(shader_get_uniform(_sh, "u_count"), _n);
    shader_set_uniform_f(shader_get_uniform(_sh, "u_aspect"), _cw / _ch);
    shader_set_uniform_f_array(shader_get_uniform(_sh, "u_center"),   _centers);
    shader_set_uniform_f_array(shader_get_uniform(_sh, "u_radius"),   _radii);
    shader_set_uniform_f_array(shader_get_uniform(_sh, "u_width"),    _widths);
    shader_set_uniform_f_array(shader_get_uniform(_sh, "u_strength"), _strengths);
    return true;
}
