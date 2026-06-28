scr_bulb_spawn_crystal_lights("near_tiles");



// Bake occluders here — Room Start runs on frozen instances; Alarm does not.

scr_bulb_destroy_all_tilemap_occluders(renderer, tilemap_occluders);

tilemap_occluders = scr_bulb_build_room_occluders(renderer);

occluders_built = true;

