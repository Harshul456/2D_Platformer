/// obj_enemy_parent — grounded tilemap FSM (see scr_enemy_grounded).
/// Defaults assume ~64×64 bottom-centered collision. For 32×32, lower
/// gnd_ledge_forward_px (~18), gnd_eye_y (~−28), attack_range (~24–32), and grav if desired.
/// Optional: Sprite Editor → manual collision mask for less snagging in 1-tile gaps.

// Collision tilemap: prefer same layer as player Room Start (lay_collision), then Collisions.
var _collision_layer = layer_get_id("lay_collision");
gnd_tilemap = layer_tilemap_get_id(_collision_layer);
if (gnd_tilemap == -1) {
    _collision_layer = layer_get_id("Collisions");
    gnd_tilemap = layer_tilemap_get_id(_collision_layer);
}

gnd_state = 0; // GND_STATE_PATROL
move_speed = 1.15;
sight_range = 300;
// attack_range = max horizontal gap (px) between bbox edges to enter ATTACK (not center-to-center).
attack_range = 30;
gnd_attack_vertical_overlap_min = 10;

gnd_patrol_x1 = x - 140;
gnd_patrol_x2 = x + 140;
gnd_patrol_half_width = 140;
gnd_facing = (random(1) < 0.5) ? -1 : 1;
image_xscale = abs(image_xscale) * gnd_facing;

gnd_eye_x = 24;
gnd_eye_y = -50;

gnd_attack_duration = 28;
gnd_attack_timer = 0;
gnd_attack_lunge = 3;
gnd_attack_lunge_frames = 9;

gnd_hurt_stun_frames = 22;
gnd_hurt_stun_timer = 0;
gnd_knock_h = 0;
gnd_hurt_knockback_h = 4.5;
gnd_hp = 100;
hit_blink_timer = 0;

gnd_touch_damage = 10;
gnd_touch_damage_patrol = 8;
gnd_touch_damage_chase = 10;
gnd_touch_damage_attack = 14;
gnd_touch_knock_x = 4.2;
gnd_touch_knock_y = -3;

grav = 0.54;
vsp = 0;
vsp_max_fall = 14;

gnd_los_sample_px = 6;
gnd_ledge_forward_px = 36;
gnd_foot_inset = 12;
