global_init();

// Default camera zone for room_test (full room scroll bounds)
with (instance_find(obj_camera_zone, 0)) {
    zone_w = room_width;
    zone_h = room_height;
    default_zone = true;
    zone_min_x = x;
    zone_min_y = y;
    zone_max_x = x + zone_w;
    zone_max_y = y + zone_h;
}

audio_play_sound(s_alone, 1, true);
