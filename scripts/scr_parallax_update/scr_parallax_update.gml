/// @function scr_parallax_update()
/// @description Offsets mid_tiles, far_tiles, and Tiles_Waterfall.
/// Waterfall uses the same horizontal factor as mid; its Y is driven by waterfall scroll.
/// Call at the end of scr_camera_control() after camera_set_view_pos().
function scr_parallax_update() {
    var _ctrl = obj_camera_controller;
    if (!variable_instance_exists(_ctrl, "parallax_ready") || !_ctrl.parallax_ready) exit;

    var _cx = camera_get_view_x(_ctrl.cam) - _ctrl.parallax_cam_origin_x;
    var _cy = 0;
    var _need_y = (_ctrl.par_mid_y != 0) || (variable_instance_exists(_ctrl, "par_far_y") && _ctrl.par_far_y != 0);
    if (_need_y) {
        _cy = camera_get_view_y(_ctrl.cam) - _ctrl.parallax_cam_origin_y;
    }
    var _vc = (variable_instance_exists(_ctrl, "par_vert_clamp") ? _ctrl.par_vert_clamp : 48);

    var _mid = layer_get_id("mid_tiles");
    if (_mid != -1) {
        layer_x(_mid, _ctrl.mid_start_x + (_cx * _ctrl.par_mid_x));
        if (_ctrl.par_mid_y != 0) {
            var _my_raw = _ctrl.mid_start_y + (_cy * _ctrl.par_mid_y);
            layer_y(_mid, clamp(_my_raw, _ctrl.mid_start_y - _vc, _ctrl.mid_start_y + _vc));
        }
    }

    var _far = layer_get_id("far_tiles");
    if (_far != -1 && variable_instance_exists(_ctrl, "far_start_x")) {
        var _far_x = variable_instance_exists(_ctrl, "par_far_x") ? _ctrl.par_far_x : _ctrl.par_mid_x;
        layer_x(_far, _ctrl.far_start_x + (_cx * _far_x));
        var _far_y = variable_instance_exists(_ctrl, "par_far_y") ? _ctrl.par_far_y : 0;
        if (_far_y != 0) {
            var _fy_raw = _ctrl.far_start_y + (_cy * _far_y);
            layer_y(_far, clamp(_fy_raw, _ctrl.far_start_y - _vc, _ctrl.far_start_y + _vc));
        }
    }

    // Waterfall: same horizontal drift as mid + wrapped vertical scroll.
    scr_waterfall_parallax_apply(_ctrl);
}
