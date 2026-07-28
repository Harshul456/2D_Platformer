// Room Start — re-anchor above floor once collision tilemap is ready.
if (gnd_tilemap != -1 && gnd_tilemap != noone) {
    global.tilemap_collision_id = gnd_tilemap;
}
scr_enemy_air_anchor_above_floor(enemy_air_altitude);
home_x = x;
spawn_x = x;
gnd_patrol_x1 = x - gnd_patrol_half_width;
gnd_patrol_x2 = x + gnd_patrol_half_width;
