/// Razor hit-slash — neon outer + white core, shockwave ring, starburst sparks.
image_speed = 0;
// Drawn with the other gameplay FX, after the room, so cave fog cannot bury it.
visible = false;

life_max = 7;
life_timer = life_max;

// Overridden by spawn helper before debris burst
slash_angle = 0;
slash_length = 56;
color_outer = c_aqua;
color_inner = c_white;

// Spike pogo: sparks travel only along slash_angle, under the blade.
outward_only = false;

// Detail layers (lazily built on first Draw once slash_length is finalized)
fx_built = false;
star_n = 0;
star_ang = [];
star_len = [];
ring_r = 0;
