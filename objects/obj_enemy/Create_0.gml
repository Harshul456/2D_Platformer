// @description obj_enemy — tilemap defaults from parent + Hollow Knight 6-state crystal FSM.
event_inherited();

// ENEMY_STATE lives in scr_enemy_ai (script scope for obj_player reads).
state = ENEMY_STATE.PATROL;
state_timer = 0;

obj_enemy_health = 100;
moveSpeed = 0.85;
chaseRange = 500;
chase_stop_extra = 42;

stunTimer = 0;
hit_blink_timer = 0;
knockbackX = 0;
knockback_pending_x = 0;
knockback_pending_y = 0;
knockback_pending_lift = false;
FINISHER_LIFT_OFFSET = 4;

hsp = 0;
vsp = 0;
grv = 0.5;

base_xscale = abs(image_xscale);
if (base_xscale == 0) base_xscale = 1;
image_xscale = base_xscale;
base_yscale = image_yscale;

// HK rhythm: telegraph → dash → recoil (+ stunned on nail hit)
attack_hit_dealt = false;
attack_frame = 0;
dash_sweep_prev_x = x;
attack_cooldown = 0;
attack_cooldown_max_frames = 72;
enemy_post_hit_cooldown_frames = 55;
enemy_telegraph_frames = 24;
enemy_attack_dash_frames = 14;
enemy_attack_dash_hsp = 3.6;
enemy_recover_frames = 32;
enemy_approach_slow_mult = 1.75;
enemy_approach_slow_factor = 0.5;
enemy_attack_damage = 12;
enemy_attack_hsp_push = 4.8;

home_x = x;
spawn_x = home_x;
patrol_range_px = 180;
patrol_dir = (random(1) < 0.5) ? -1 : 1;
scr_enemy_set_facing(patrol_dir);
lost_los_timer = 0;
chase_path_blocked_timer = 0;
chase_wall_stuck_timer = 0;
patrol_flip_cooldown = 0;
chase_reaggro_cooldown = 0;
enemy_hmove_blocked = false;

telegraph_shake_x = 0;
telegraph_shake_y = 0;
impact_spark_list = [];

shelf_bb_bottom_prev = bbox_bottom;
enemy_grounded = true;
ENEMY_FOOT_PROBE_HALF_WIDTH = 3;
ENEMY_HMOVE_HALF_WIDTH = 14;
ENEMY_HMOVE_USE_HEAD_PROBE = false; // Tall crystal — head samples hit cave tiles asymmetrically on left

// Tilemap available from parent Create before player Room Start.
if (gnd_tilemap != -1 && gnd_tilemap != noone && global.tilemap_collision_id == noone) {
    global.tilemap_collision_id = gnd_tilemap;
}

scr_enemy_floating_hover_init();
enemy_is_floating = false;

// Room Y often matches background art, not lay_collision — snap down to real floor.
scr_enemy_snap_to_collision_floor();
home_x = x;
spawn_x = home_x;

enemy_ai_enabled = true;
