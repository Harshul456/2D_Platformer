// Pit / hazard reset — dissolve deaths use the fade sequence instead.
scr_player_respawn(true);
scr_player_clear_hurt_state();
death_is_dissolve = false;
death_fade_phase = DEATH_SEQ.NONE;
death_fade_alpha = 0;
death_seq_timer = 0;
sprite_index = spr_mc_idle;
image_index = 0;
image_speed = 1;
image_alpha = 1;
