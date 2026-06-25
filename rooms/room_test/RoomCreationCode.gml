global_init();

// Default camera zone for room_test (full room scroll bounds)
// Use room origin — not the zone instance x/y (inst is at 64,128 for editor visibility only).
with (instance_find(obj_camera_zone, 0)) {
    zone_w = room_width;
    zone_h = room_height;
    default_zone = true;
    zone_min_x = 0;
    zone_min_y = 0;
    zone_max_x = room_width;
    zone_max_y = room_height;
}

audio_play_sound(s_alone, 1, true);
