var _t = image_alpha;
if (_t <= 0.02) exit;

var _px = floor(x);
var _py = floor(y);
var _hw = stain_w * 0.5;
var _hh = stain_h * 0.5;

var _old_blend = gpu_get_blendmode();
var _old_alpha = draw_get_alpha();

// Soft purple melt under the stain
gpu_set_blendmode(bm_add);
draw_set_alpha(_t * 0.25);
draw_set_color(glow_col);
draw_ellipse(_px - _hw - 2, _py - _hh - 1, _px + _hw + 2, _py + _hh + 1, false);

// Opaque void blot
gpu_set_blendmode(_old_blend);
draw_set_alpha(_t);
draw_set_color(col);
draw_ellipse(_px - _hw, _py - _hh, _px + _hw, _py + _hh, false);

// Inner darker core
draw_set_alpha(_t * 0.9);
draw_set_color(make_color_rgb(12, 8, 16));
draw_ellipse(_px - _hw * 0.45, _py - _hh * 0.4, _px + _hw * 0.45, _py + _hh * 0.4, false);

draw_set_alpha(_old_alpha);
draw_set_color(c_white);
