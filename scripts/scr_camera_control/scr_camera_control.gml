/// @function scr_camera_control
/// @description MMX-style zone bounds + border scroll; state-based look-ahead only (no anchor/lerp follow).
function scr_camera_control() {
    if (!instance_exists(obj_player)) exit;

    var _p = obj_player;
    var _cam_x = camera_get_view_x(cam);
    var _cam_y = camera_get_view_y(cam);

    var _player_moved = (abs(_p.x - camera_prev_player_x) > 0.001 || abs(_p.y - camera_prev_player_y) > 0.001);
    // Hitstop freezes the player — don't drift the view toward look-ahead / min-scroll alone.
    if (global.hitstop > 0 && !_player_moved) {
        exit;
    }

    // Wall slide: no horizontal look-ahead; still border-scroll to follow player (mostly vertical).
    var _wall_cling_cam = (!_p.grounded && _p.wall_side != 0 && _p.vsp > 0
        && _p.wall_jump_kick_hold_timer <= 0 && _p.wall_jump_extend_timer <= 0);

    if (_wall_cling_cam) {
        cam_look_ahead = lerp(cam_look_ahead, 0, 0.18);
    } else if (global.hitstop <= 0) {
        // --- Look-ahead (state-based; does not lerp the view itself) ---
        var _look_target = 0;
        var _look_speed = 0.12;
        if (_p.attacking) {
            _look_target = 90 * _p.last_direction;
            _look_speed = 0.08;
        } else if (_p.is_sprinting) {
            _look_target = 130 * _p.last_direction;
            _look_speed = 0.14;
        } else if (!_p.grounded) {
            _look_target = 100 * _p.last_direction;
            _look_speed = 0.10;
        } else if (abs(_p.hsp) > 0.5) {
            _look_target = 120 * _p.last_direction;
            _look_speed = 0.12;
        } else {
            _look_target = 40 * _p.last_direction;
            _look_speed = 0.06;
        }
        cam_look_ahead = lerp(cam_look_ahead, _look_target, _look_speed);
    }

    var _half_h = (_p.bbox_bottom - _p.bbox_top) * 0.5;
    // Squash coil scales the bbox — normalize so dash deform doesn't jerk the view.
    var _squash_y = _p.image_yscale / _p.image_base_scale;
    if (_squash_y > 0.01) _half_h /= _squash_y;
    var _px = floor(_p.x + cam_look_ahead);
    var _py = floor(_p.y - _half_h);

    var _min_x = global.camera_min_x;
    var _max_x = global.camera_max_x;
    var _min_y = global.camera_min_y;
    var _max_y = global.camera_max_y;

    // Offset from view center (MMX obj_camera_rds)
    var _ox = ceil(_px - (_cam_x + cam_w * 0.5));
    var _oy = ceil(_py - (_cam_y + cam_h * 0.5));

    // Vertical dead zone while airborne — small jumps don't scroll Y
    if (!_p.grounded) {
        var _vbor_min = global.camera_vbor_min_y;
        var _vbor_max = global.camera_vbor_max_y;
        if (_oy > _vbor_max) _oy -= _vbor_max;
        else if (_oy < _vbor_min) _oy -= _vbor_min;
        else _oy = 0;
    }

    _ox = max(_ox, _min_x - _cam_x);
    _ox = min(_ox, _max_x - (_cam_x + cam_w));
    _oy = max(_oy, _min_y - _cam_y);
    _oy = min(_oy, _max_y - (_cam_y + cam_h));

    if (_wall_cling_cam) _ox = 0;

    var _dx = abs(_p.x - camera_prev_player_x);
    var _dy = abs(_p.y - camera_prev_player_y);
    var _xspeed = _dx;
    var _yspeed = _dy;
    if (global.hitstop <= 0) {
        // Min scroll only when the player actually moved on that axis (avoids vertical jitter on horizontal dash).
        if (_dx > 0.001) _xspeed = max(_dx, global.camera_scroll_min_x);
        if (_dy > 0.001) _yspeed = max(_dy, global.camera_scroll_min_y);
    }
    if (abs(_ox) > _xspeed) _ox = _xspeed * sign(_ox);
    if (abs(_oy) > _yspeed) _oy = _yspeed * sign(_oy);

    camera_prev_player_x = _p.x;
    camera_prev_player_y = _p.y;

    var _new_x = _cam_x;
    var _new_y = _cam_y;
    if (_ox < 0 && _cam_x >= _min_x) _new_x = max(floor(_cam_x + _ox), _min_x);
    if (_ox > 0 && (_cam_x + cam_w) <= _max_x) _new_x = min(floor(_cam_x + _ox), _max_x - cam_w);
    if (_oy < 0 && _cam_y >= _min_y) _new_y = max(_cam_y + _oy, _min_y);
    if (_oy > 0 && (_cam_y + cam_h) <= _max_y) _new_y = min(_cam_y + _oy, _max_y - cam_h);

    camera_set_view_pos(cam, _new_x, _new_y);
    scr_parallax_update();
}
