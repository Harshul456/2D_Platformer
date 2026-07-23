var _old_blend = gpu_get_blendmode();
var _old_alpha = draw_get_alpha();

draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
    image_xscale, image_yscale, 0, image_blend, image_alpha);

gpu_set_blendmode(bm_add);
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
    image_xscale, image_yscale, 0, c_aqua, image_alpha * 0.35);
gpu_set_blendmode(_old_blend);
draw_set_alpha(_old_alpha);
draw_set_color(c_white);
