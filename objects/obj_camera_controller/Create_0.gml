// --- CAMERA CONTROLLER CREATE EVENT ---

// Camera reference
cam = view_camera[0];
cam_w = camera_get_view_width(cam);
cam_h = camera_get_view_height(cam);

// Target to follow (set in Room Start)
target = noone;

// Camera state
camera_anchor_x = 0;
camera_anchor_y = 0;
cam_look_ahead = 0;

// Camera lock variables (for attacks)
was_attacking = false;
locked_cam_x = 0;
locked_cam_y = 0;

// IMPORTANT: Initialize camera position immediately
// This prevents the "slide on start" issue
if (instance_exists(obj_player)) {
    target = obj_player;
    
    // Set initial position centered on player
    camera_anchor_x = target.x;
    camera_anchor_y = target.y - 32;
    
    var _start_x = camera_anchor_x - (cam_w / 2);
    var _start_y = camera_anchor_y - (cam_h / 2);
    
    // Clamp to room bounds
    _start_x = clamp(_start_x, 0, room_width - cam_w);
    _start_y = clamp(_start_y, 0, room_height - cam_h);
    
    // Set camera immediately (no lerp on first frame)
    camera_set_view_pos(cam, _start_x, _start_y);
}