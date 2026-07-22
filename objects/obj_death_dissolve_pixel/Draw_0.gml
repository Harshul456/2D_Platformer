var _t = image_alpha;
if (_t <= 0.02) exit;

var _s = max(1, round(size * power(_t, 0.45)));
var _px = floor(x);
var _py = floor(y);

var _old_blend = gpu_get_blendmode();
var _old_alpha = draw_get_alpha();

// Soft void glow (additive) — reads as shadow melting into the cave dark
gpu_set_blendmode(bm_add);
draw_set_alpha(_t * 0.35);
draw_set_color(glow_col);
draw_rectangle(_px - _s - 1, _py - _s - 1, _px + _s + 1, _py + _s + 1, false);

// Hard pixel core
gpu_set_blendmode(_old_blend);
draw_set_alpha(_t);
draw_set_color(col);
draw_rectangle(_px - _s, _py - _s, _px + _s, _py + _s, false);

draw_set_alpha(_old_alpha);
draw_set_color(c_white);
