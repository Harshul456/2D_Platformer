global_init();

// This room is one screen. The placed zone marker should frame the whole room,
// not a 640x360 box starting at the marker.
with (obj_camera_zone) {
    zone_w = room_width;
    zone_h = room_height;
    default_zone = true;
    zone_apply_bounds = true;
    zone_look_ahead_mult = 1;
    zone_look_ahead_bonus = 0;
    zone_look_ahead_trail_margin = 0.16;
    zone_priority = 0;
    zone_min_x = 0;
    zone_min_y = 0;
    zone_max_x = room_width;
    zone_max_y = room_height;
}