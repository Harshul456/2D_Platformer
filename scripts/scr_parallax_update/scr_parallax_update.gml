/// @function scr_parallax_update()
/// @description Updates near/mid/far tile layer positions for parallax scrolling.
/// Called at the END of scr_camera_control() after camera_set_view_pos() has committed
/// the final camera position for this frame. Reads camera state directly via
/// camera_get_view_x/y to avoid stale local variable scope issues.
function scr_parallax_update() {

    var _ctrl = obj_camera_controller;

    // Guard: if Create Event didn't finish initialising anchors, skip silently
    if (!variable_instance_exists(_ctrl, "parallax_ready") || !_ctrl.parallax_ready) exit;

    // --- READ FINAL COMMITTED CAMERA POSITION ---
    var _cam = _ctrl.cam;
    var _cx = camera_get_view_x(_cam) - _ctrl.parallax_cam_origin_x;
var _cy = camera_get_view_y(_cam) - _ctrl.parallax_cam_origin_y;;

    // --- LAYER ID RESOLUTION ---
    var _lid_near = layer_get_id("near_tiles");
    var _lid_mid  = layer_get_id("mid_tiles");
    var _lid_far  = layer_get_id("far_tiles");

    // --- VERTICAL CLAMP PARAMETERS ---
    var _vc = _ctrl.par_vert_clamp;

    // --- NEAR LAYER ---
    if (layer_exists(_lid_near)) {
        var _nx     = _ctrl.near_start_x + (_cx * _ctrl.par_near_x);
        var _ny_raw = _ctrl.near_start_y + (_cy * _ctrl.par_near_y);
        var _ny     = clamp(_ny_raw, _ctrl.near_start_y - _vc, _ctrl.near_start_y + _vc);
        layer_x(_lid_near, _nx);
        layer_y(_lid_near, _ny);
    }

    // --- MID LAYER ---
    if (layer_exists(_lid_mid)) {
        var _mx     = _ctrl.mid_start_x + (_cx * _ctrl.par_mid_x);
        var _my_raw = _ctrl.mid_start_y + (_cy * _ctrl.par_mid_y);
        var _my     = clamp(_my_raw, _ctrl.mid_start_y - _vc, _ctrl.mid_start_y + _vc);
        layer_x(_lid_mid, _mx);
        layer_y(_lid_mid, _my);
    }

    // --- FAR LAYER ---
    if (layer_exists(_lid_far)) {
        var _fx     = _ctrl.far_start_x + (_cx * _ctrl.par_far_x);
        var _fy_raw = _ctrl.far_start_y + (_cy * _ctrl.par_far_y);
        var _fy     = clamp(_fy_raw, _ctrl.far_start_y - _vc, _ctrl.far_start_y + _vc);
        layer_x(_lid_far, _fx);
        layer_y(_lid_far, _fy);
    }
}