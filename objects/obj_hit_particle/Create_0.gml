/// Blocky pixel debris — heavy friction, glow + motion-streak trail.
// Bulb rooms draw this in Post-Draw so fog cannot bury it. Without that controller, draw normally.
visible = !instance_exists(obj_bulb_controller);
friction = 0.25;
size = irandom_range(2, 5);
life_max = irandom_range(10, 18);
life = life_max;

// Overridable look
col = c_white;                 // Hard pixel core
glow_col = c_aqua;             // Additive glow + streak tint
streak = true;                 // Draw a motion trail behind velocity
