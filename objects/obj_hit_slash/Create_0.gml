/// Razor hit-slash — neon outer + white core, shockwave ring, starburst sparks.
image_speed = 0;
visible = false; // Drawn in Bulb Post-Draw so fog/glow cannot bury it

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
