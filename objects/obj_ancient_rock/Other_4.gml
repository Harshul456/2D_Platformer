// Room Start — keep the float on the placed y. The tilemap is only for bolts and walls.
if (gnd_tilemap != -1 && gnd_tilemap != noone) {
    global.tilemap_collision_id = gnd_tilemap;
}
ystart = y;
home_x = x;
spawn_x = x;
gnd_patrol_x1 = x - gnd_patrol_half_width;
gnd_patrol_x2 = x + gnd_patrol_half_width;
