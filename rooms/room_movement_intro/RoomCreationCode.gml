global_init();

// Camera zones — intro (wide/flat) → tight (low ceiling) → open (vertical climb)
with (instance_find(obj_camera_zone, 0)) {
    // Section 1: spawn + first jumps (cols 0–59)
    zone_w = 1920;
    zone_h = room_height;
    default_zone = true;
    zone_apply_vbor = true;
    zone_vbor_min_y = -72;
    zone_vbor_max_y = 48;
    zone_min_x = x;
    zone_min_y = y;
    zone_max_x = x + zone_w;
    zone_max_y = y + zone_h;
}

with (instance_find(obj_camera_zone, 1)) {
    // Section 2: low-ceiling tunnel + one-way shaft (cols 60–99)
    zone_w = 1280;
    zone_h = room_height;
    default_zone = false;
    zone_apply_vbor = true;
    zone_vbor_min_y = -96;
    zone_vbor_max_y = 28;
    zone_min_x = x;
    zone_min_y = 608;
    zone_max_x = x + zone_w;
    zone_max_y = room_height;
}

with (instance_find(obj_camera_zone, 2)) {
    // Section 3: tall room, ladder + platforms (cols 100–119)
    zone_w = 640;
    zone_h = room_height;
    default_zone = false;
    zone_apply_vbor = true;
    zone_vbor_min_y = -56;
    zone_vbor_max_y = 72;
    zone_min_x = x;
    zone_min_y = y;
    zone_max_x = x + zone_w;
    zone_max_y = y + zone_h;
}

audio_play_sound(s_tutorial_stage, 1, true);
