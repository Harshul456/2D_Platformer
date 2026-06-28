// --- CAMERA CONTROLLER CREATE ---
cam = view_camera[0];
cam_w = camera_get_view_width(cam);
cam_h = camera_get_view_height(cam);

cam_look_ahead = 0;
camera_prev_player_x = 0;
camera_prev_player_y = 0;

// Zone bounds (obj_camera_zone updates globals; fallback = whole room)
global.camera_current_zone = -1;
global.camera_min_x = 0;
global.camera_min_y = 0;
global.camera_max_x = room_width;
global.camera_max_y = room_height;

if (instance_exists(obj_player)) {
    camera_prev_player_x = obj_player.x;
    camera_prev_player_y = obj_player.y;
    var _half_h = (obj_player.bbox_bottom - obj_player.bbox_top) * 0.5;
    var _sx = clamp(floor(obj_player.x - cam_w * 0.5), global.camera_min_x, global.camera_max_x - cam_w);
    var _sy = clamp(floor(obj_player.y - _half_h - cam_h * 0.5), global.camera_min_y, global.camera_max_y - cam_h);
    camera_set_view_pos(cam, _sx, _sy);
}

// Parallax — mid_tiles rock wall only; horizontal drift only (no Y shift = no top/bottom gaps).
parallax_ready = false;
par_mid_x = 0.35;
par_mid_y = 0;
mid_start_x = 0;
mid_start_y = 0;
parallax_cam_origin_x = camera_get_view_x(cam);
parallax_cam_origin_y = camera_get_view_y(cam);
var _mid_layer = layer_get_id("mid_tiles");
if (_mid_layer != -1) {
    mid_start_x = layer_get_x(_mid_layer);
    mid_start_y = layer_get_y(_mid_layer);
    parallax_ready = true;
}
