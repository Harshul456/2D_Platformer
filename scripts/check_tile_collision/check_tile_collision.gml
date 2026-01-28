function check_tile_collision(_x, _y) {

    // Original logic: Check if the tile's collision data is non-zero (i.e., solid).
    // This function is known to compile and run without the "Variable not set" error.
    return tilemap_get_at_pixel(global.tilemap_collision_id, _x, _y) != 0;

}