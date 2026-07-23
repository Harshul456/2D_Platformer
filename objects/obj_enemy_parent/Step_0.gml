/// Gravity, tile collision, knockback, and FSM — scr_enemy_grounded_step.
if (global.hitstop > 0) exit;
if (!scr_time_scale_should_tick()) exit;

scr_enemy_grounded_step();
