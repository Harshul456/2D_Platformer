var _t = life / max(1, life_max);
var _sz = size * power(max(0, _t), 0.55);
if (_sz <= 0.4) exit;

var _s  = max(1, round(_sz));
var _px = floor(x);
var _py = floor(y);

var _old_blend = gpu_get_blendmode();
var _spd = point_distance(0, 0, hspeed, vspeed);

// --- Motion streak behind velocity (additive) ---
if (streak && _spd > 0.6) {
    var _len = min(18, _spd * 2.4) * _t;
    var _tx = floor(_px - lengthdir_x(_len, direction));
    var _ty = floor(_py - lengthdir_y(_len, direction));
    gpu_set_blendmode(bm_add);
    draw_set_color(glow_col);
    draw_line_width(_tx, _ty, _px, _py, max(1, _s));
}

// --- Glow halo (additive, slightly larger) ---
gpu_set_blendmode(bm_add);
draw_set_color(glow_col);
draw_rectangle(_px - _s - 1, _py - _s - 1, _px + _s + 1, _py + _s + 1, false);

// --- Hard pixel core ---
gpu_set_blendmode(_old_blend);
draw_set_color(col);
draw_rectangle(_px - _s, _py - _s, _px + _s, _py + _s, false);

draw_set_color(c_white);
