// --- obj_camera END STEP EVENT ---
// Hollow Knight-style state-based camera system

// Check if player exists
if (!instance_exists(obj_player)) exit;

// --- 1. CURRENT CAMERA POSITION ---
var _cam_x = camera_get_view_x(cam);
var _cam_y = camera_get_view_y(cam);

// --- 2. SMOOTH ANCHOR (FOLLOWS PLAYER) ---
// During attacks, follow player more closely to prevent losing them during combos
var _anchor_speed = obj_player.attacking ? 0.15 : 0.08;
camera_anchor_x = lerp(camera_anchor_x, obj_player.x, _anchor_speed);
// Vertical anchor adapts to character height (supports 64x64 now, 96x96 later)
var _player_half_h = (obj_player.bbox_bottom - obj_player.bbox_top) * 0.5;
var _anchor_y_speed = 0.1;
// When falling, anchor must keep up so camera doesn't lag behind
if (!obj_player.grounded && obj_player.vsp > 0) {
    _anchor_y_speed = 0.25; // Faster follow when falling (was fixed 0.1 = camera lagged)
}
camera_anchor_y = lerp(camera_anchor_y, obj_player.y - _player_half_h, _anchor_y_speed);

// --- 3. STATE-BASED LOOK-AHEAD SYSTEM ---
var _look_target = 0;
var _look_speed = 0.12;
var _camera_speed = 0.1;

// Determine player state and adjust camera accordingly
if (obj_player.attacking) {
    // ATTACKING: Moderate look-ahead to see targets, slower camera for stability
    _look_target = 90 * obj_player.last_direction;
    _look_speed = 0.08;  // Slower transition during attacks
    _camera_speed = 0.06; // More stable camera
    
} else if (obj_player.is_dashing) {
    // DASHING: Strong look-ahead to see where you're going
    _look_target = 150 * obj_player.last_direction;
    _look_speed = 0.15;  // Quick transition
    _camera_speed = 0.12; // Faster camera to keep up
    
} else if (!obj_player.grounded) {
    // IN AIR: Moderate look-ahead; when falling use faster vertical follow so camera keeps up
    _look_target = 100 * obj_player.last_direction;
    _look_speed = 0.10;
    _camera_speed = (obj_player.vsp > 0) ? 0.18 : 0.08; // Faster when falling
    
} else if (abs(obj_player.hsp) > 0.5) {
    // WALKING/RUNNING: Normal look-ahead
    _look_target = 120 * obj_player.last_direction;
    _look_speed = 0.12;
    _camera_speed = 0.1;
    
} else {
    // IDLE/STANDING STILL: Minimal look-ahead, centers on player
    _look_target = 40 * obj_player.last_direction;
    _look_speed = 0.06; // Slow return to center
    _camera_speed = 0.08;
}

// Smoothly transition look-ahead with state-specific speed
cam_look_ahead = lerp(cam_look_ahead, _look_target, _look_speed);

// --- 4. CALCULATE TARGET CAMERA POSITION ---
var _target_x = camera_anchor_x + cam_look_ahead - (cam_w / 2);
var _target_y = camera_anchor_y - (cam_h / 2);

// --- 5. SMOOTH CAMERA MOVEMENT (with state-specific speed) ---
var _final_x = lerp(_cam_x, _target_x, _camera_speed);
var _final_y = lerp(_cam_y, _target_y, _camera_speed);

// --- 6. CLAMP TO ROOM BOUNDS ---
_final_x = clamp(_final_x, 0, room_width - cam_w);
_final_y = clamp(_final_y, 0, room_height - cam_h);

// --- 7. APPLY ---
camera_set_view_pos(cam, floor(_final_x), floor(_final_y));