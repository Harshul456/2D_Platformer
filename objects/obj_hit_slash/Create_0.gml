/// Razor hit-slash — neon outer + white core, shockwave ring, starburst sparks.
image_speed = 0;
// Bulb rooms draw this in Post-Draw so fog cannot bury it. Without that controller, draw normally.
visible = !instance_exists(obj_bulb_controller);

life_max = 7;
life_timer = life_max;

// Overridden by spawn helper before debris burst
slash_angle = 0;
slash_length = 56;
color_outer = c_aqua;
color_inner = c_white;

// Detail layers (lazily built on first Draw once slash_length is finalized)
fx_built = false;
star_n = 0;
star_ang = [];
star_len = [];
ring_r = 0;
