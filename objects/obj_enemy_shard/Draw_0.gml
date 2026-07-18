// Crisp geometric crystal shard — a spinning triangle that scales down before vanishing.
var _s = size * (life / (life + 10));
if (_s <= 0.5) exit;

var _cx = floor(x);
var _cy = floor(y);

// Three points around the center, rotated by angle → a sharp shard.
var _x1 = floor(_cx + lengthdir_x(_s * 1.3, angle - 90));
var _y1 = floor(_cy + lengthdir_y(_s * 1.3, angle - 90));
var _x2 = floor(_cx + lengthdir_x(_s, angle + 138));
var _y2 = floor(_cy + lengthdir_y(_s, angle + 138));
var _x3 = floor(_cx + lengthdir_x(_s, angle + 42));
var _y3 = floor(_cy + lengthdir_y(_s, angle + 42));

// Solid body
draw_set_color(shard_color);
draw_triangle(_x1, _y1, _x2, _y2, _x3, _y3, false);

// Additive glint so shards read like lit crystal
var _ob = gpu_get_blendmode();
gpu_set_blendmode(bm_add);
draw_set_alpha(0.5 * clamp(life / max(1, life_max), 0, 1));
draw_triangle(_x1, _y1, _x2, _y2, _x3, _y3, false);
gpu_set_blendmode(_ob);

draw_set_alpha(1);
draw_set_color(c_white);
