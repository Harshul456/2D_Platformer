/// obj_ancient_rock — aerial floater. Same hover bob as crystal core, held higher in the air.
event_inherited();

sprite_index = spr_ancient_rock;
mask_index = spr_ancient_rock;

// Shared parent HP; body touch damage disabled (projectile only).
gnd_hp = 120;
gnd_touch_enabled = false;
gnd_touch_damage = 0;
gnd_touch_damage_patrol = 0;
gnd_touch_damage_chase = 0;
gnd_touch_damage_attack = 0;
gnd_hurt_knockback_h = 3.2;
gnd_hurt_stun_frames = 18;

// Air locomotion
moveSpeed = 0.7;
chaseRange = 280;
sight_range = 280;
hsp = 0;
vsp = 0;
grv = 0;
enemy_grounded = false;
enemy_ai_enabled = true;

// Same bob feel as crystal core, locked to an elevated float line
scr_enemy_floating_hover_init();
enemy_is_floating = true;
hover_amplitude = 10;
hover_cycle_seconds = 3;
hover_time_speed = (2 * pi) / (hover_cycle_seconds * max(1, room_speed));
enemy_air_altitude = 112; // px above floor — stays clearly airborne vs crystal core

// Place on collision floor then lift into air (room markers can sit on platforms)
scr_enemy_air_anchor_above_floor(enemy_air_altitude);
home_x = x;
spawn_x = x;
gnd_patrol_x1 = x - gnd_patrol_half_width;
gnd_patrol_x2 = x + gnd_patrol_half_width;

// Charge telegraph shake offsets (shared with crystal draw path)
telegraph_shake_x = 0;
telegraph_shake_y = 0;

// Hover-in-place charge → aimed bolt
scr_ancient_rock_attack_init();

// Light + charge motes aim at the teal diamond (not feet)
enemy_light_y_offset = BULB_ANCIENT_ROCK_CORE_Y_OFFSET;

// Shatter into purple crystal + grey stone
enemy_shard_palette = [
    make_colour_rgb(150, 70, 210),   // purple crystal
    make_colour_rgb(120, 55, 175),   // deep purple
    make_colour_rgb(130, 130, 138),  // grey stone
    make_colour_rgb(95, 95, 102),    // dark grey
    make_colour_rgb(175, 175, 182),  // light stone chip
    c_white
];
rock_death_started = false;

// Bulb glow — same pipeline as crystal core, blue instead of pink
crystal_kind = BULB_ANCIENT_ROCK_CRYSTAL_KIND;
enemy_bulb_light_scale = BULB_ANCIENT_ROCK_LIGHT_SCALE;
ENEMY_GLOW_SPRITE = spr_ancient_rock; // self-emissive mask until a dedicated glow sheet exists
// No enemy_glow_blend — additive overlay stays white like crystal core (blue only in Bulb light)
scr_enemy_crystal_light_init();
