var _t = life / max(1, life_max);
if (_t <= 0.02) exit;

var _px = floor(x);
var _py = floor(y);
var _arm = 10 * image_xscale;
var _thick = max(1, round(2.5 * (0.4 + _t)));
var _a = _t;

var _old_blend = gpu_get_blendmode();
var _old_alpha = draw_get_alpha();

gpu_set_blendmode(bm_add);
draw_set_alpha(_a * 0.85);
draw_set_color(flare_col);
// Horizontal / vertical cross
draw_line_width(_px - _arm, _py, _px + _arm, _py, _thick);
draw_line_width(_px, _py - _arm, _px, _py + _arm, _thick);
// Diagonal arms
var _d = _arm * 0.72;
draw_line_width(_px - _d, _py - _d, _px + _d, _py + _d, max(1, _thick - 1));
draw_line_width(_px - _d, _py + _d, _px + _d, _py - _d, max(1, _thick - 1));

// Hot core
draw_set_alpha(_a);
draw_set_color(flare_core);
draw_circle(_px, _py, max(2, 3.5 * image_xscale * 0.35), false);

gpu_set_blendmode(_old_blend);
draw_set_alpha(_old_alpha);
draw_set_color(c_white);
