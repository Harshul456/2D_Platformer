// Room Start — collision layer is guaranteed; re-snap in case Create ran before tilemap was ready.
if (gnd_tilemap != -1 && gnd_tilemap != noone) {
    global.tilemap_collision_id = gnd_tilemap;
}
scr_enemy_snap_to_collision_floor();
home_x = x;
spawn_x = home_x;
scr_enemy_floating_hover_sync_anchor();
