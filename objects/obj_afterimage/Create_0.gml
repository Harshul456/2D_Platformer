// Copy player's current appearance
sprite_index = obj_player.sprite_index;
image_index = obj_player.image_index;
image_xscale = obj_player.image_xscale;
image_yscale = obj_player.image_yscale;
image_speed = 0; // Freeze the afterimage (don't animate)

// Visual settings
image_alpha = 0.6; // Start semi-transparent
image_blend = c_white; // Can tint for effect (c_aqua, c_lime, etc.)

// Fade settings
fade_speed = 0.08; // How fast it disappears