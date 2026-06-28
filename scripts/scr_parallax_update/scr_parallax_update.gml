/// @function scr_parallax_update()
/// @description Offsets mid_tiles only — rock wall drifts slower than the camera for depth.
/// near_tiles / far_tiles are untouched (decor stays world-locked; far is unused).
/// Call at the end of scr_camera_control() after camera_set_view_pos().
function scr_parallax_update() {
    var _ctrl = obj_camera_controller;
    if (!variable_instance_exists(_ctrl, "parallax_ready") || !_ctrl.parallax_ready) exit;

    var _lid = layer_get_id("mid_tiles");
    if (_lid == -1) exit;

    var _cx = camera_get_view_x(_ctrl.cam) - _ctrl.parallax_cam_origin_x;
    var _mx = _ctrl.mid_start_x + (_cx * _ctrl.par_mid_x);
    layer_x(_lid, _mx);

    if (_ctrl.par_mid_y != 0) {
        var _cy = camera_get_view_y(_ctrl.cam) - _ctrl.parallax_cam_origin_y;
        var _my_raw = _ctrl.mid_start_y + (_cy * _ctrl.par_mid_y);
        var _vc = (variable_instance_exists(_ctrl, "par_vert_clamp") ? _ctrl.par_vert_clamp : 48);
        layer_y(_lid, clamp(_my_raw, _ctrl.mid_start_y - _vc, _ctrl.mid_start_y + _vc));
    }
}
