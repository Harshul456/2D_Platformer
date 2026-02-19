function check_tile_collision(_x, _y) {
    // Guard: room may have no collision layer or tilemap (e.g. menu room)
    if (global.tilemap_collision_id == noone) return false;
    return tilemap_get_at_pixel(global.tilemap_collision_id, _x, _y) != 0;
}