// Draw the afterimage
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y), 
                image_xscale, image_yscale, 0, 
                image_blend, image_alpha);

// Optional: Add glow/outline effect
gpu_set_blendmode(bm_add); // Additive blending for glow
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y), 
                image_xscale, image_yscale, 0, 
                c_white, image_alpha * 0.3); // Faint glow
gpu_set_blendmode(bm_normal);