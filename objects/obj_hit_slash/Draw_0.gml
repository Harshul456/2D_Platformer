// Build detail layers once slash_length is finalized (spawn sets it after Create)
if (!fx_built) {
    fx_built = true;
    star_n = irandom_range(6, 9);
    star_ang = array_create(star_n);
    star_len = array_create(star_n);
    for (var _i = 0; _i < star_n; _i++) {
        // Bias sparks along the swing axis so it reads directional, not a starburst blob
        var _bias = (irandom(1) == 0) ? slash_angle : slash_angle + 180;
        star_ang[_i] = _bias + random_range(-42, 42);
        star_len[_i] = slash_length * random_range(0.24, 0.55);
    }
}

var _life_u = clamp(life_timer / max(1, life_max), 0, 1); // 1 -> 0 over life
var _age_u  = 1 - _life_u;                                 // 0 -> 1 over life
var _cx = floor(x);
var _cy = floor(y);

var _old_blend = gpu_get_blendmode();
var _old_alpha = draw_get_alpha();
gpu_set_blendmode(bm_add);

// --- 2. Center flash (bright core, biggest on opening frames) ---
var _flash = slash_length * 0.30 * _life_u;
if (life_timer >= life_max - 2) _flash *= 1.45;
if (_flash >= 1.5) {
    draw_set_color(color_outer);
    draw_circle(_cx, _cy, floor(_flash), false);
    draw_set_color(c_white);
    draw_circle(_cx, _cy, max(1, floor(_flash * 0.45)), false);
}

// --- 3. Radiating starburst sparks (shoot outward, fade) ---
var _spark_a = _life_u;
if (_spark_a > 0.03) {
    for (var _s = 0; _s < star_n; _s++) {
        var _sl = star_len[_s] * (0.35 + 0.65 * _age_u); // grow outward
        var _in = 2 + slash_length * 0.12 * _age_u;       // drift off center
        var _a = star_ang[_s];
        var _sx1 = _cx + lengthdir_x(_in, _a);
        var _sy1 = _cy + lengthdir_y(_in, _a);
        var _sx2 = _cx + lengthdir_x(_in + _sl, _a);
        var _sy2 = _cy + lengthdir_y(_in + _sl, _a);
        draw_set_alpha(_spark_a);
        draw_set_color(color_outer);
        draw_line_width(floor(_sx1), floor(_sy1), floor(_sx2), floor(_sy2), 2);
        draw_set_color(c_white);
        draw_line_width(floor(_sx1), floor(_sy1), floor(_sx2), floor(_sy2), 1);
    }
    draw_set_alpha(1);
}

// --- 4. Main slash line (halo + neon + white core) ---
var _len_scale = power(_life_u, 0.55); // rapid contraction, not linear fade
var _half_len = (slash_length * _len_scale) * 0.5;

var _x1 = floor(x - lengthdir_x(_half_len, slash_angle));
var _y1 = floor(y - lengthdir_y(_half_len, slash_angle));
var _x2 = floor(x + lengthdir_x(_half_len, slash_angle));
var _y2 = floor(y + lengthdir_y(_half_len, slash_angle));

var _thick_outer, _thick_inner;
if (life_timer >= life_max - 2) {
    _thick_outer = 7; _thick_inner = 3;
} else if (life_timer >= life_max - 4) {
    _thick_outer = 4; _thick_inner = 2;
} else {
    _thick_outer = 2; _thick_inner = 0;
}

if (_thick_outer > 0 && _half_len >= 0.5) {
    // Soft wide halo underneath
    draw_set_alpha(0.30);
    draw_set_color(color_outer);
    draw_line_width(_x1, _y1, _x2, _y2, _thick_outer + 5);
    draw_set_alpha(1);

    // Neon body
    draw_set_color(color_outer);
    draw_line_width(_x1, _y1, _x2, _y2, _thick_outer);

    // White core
    if (_thick_inner > 0) {
        draw_set_color(color_inner);
        draw_line_width(_x1, _y1, _x2, _y2, _thick_inner);
    }

    // Jagged glitch offset on opening frames
    if (life_timer >= life_max - 2) {
        draw_set_color(color_inner);
        draw_line_width(_x1 + 3, _y1 - 1, _x2 + 3, _y2 - 1, 1);
    }
}

gpu_set_blendmode(_old_blend);
draw_set_alpha(_old_alpha);
draw_set_color(c_white);
