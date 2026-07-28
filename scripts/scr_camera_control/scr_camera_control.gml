/// @function scr_camera_clear_shake
/// @description Zero any pending screen shake (death / respawn).
function scr_camera_clear_shake() {
    if (!instance_exists(obj_camera_controller)) return;
    with (obj_camera_controller) {
        cam_shake_mag = 0;
        cam_shake_timer = 0;
    }
}

/// @function scr_camera_zone_activate
/// @description Apply this obj_camera_zone's bounds / look-ahead / vbor to globals.
function scr_camera_zone_activate() {
    global.camera_current_zone = id;
    if (zone_apply_bounds) {
        global.camera_min_x = zone_min_x;
        global.camera_min_y = zone_min_y;
        global.camera_max_x = zone_max_x;
        global.camera_max_y = zone_max_y;
    }
    global.camera_look_ahead_mult = zone_look_ahead_mult;
    global.camera_look_ahead_bonus = zone_look_ahead_bonus;
    global.camera_look_ahead_trail_margin = zone_look_ahead_trail_margin;
    if (zone_apply_vbor) {
        global.camera_vbor_min_y = zone_vbor_min_y;
        global.camera_vbor_max_y = zone_vbor_max_y;
    }
}

/// @function scr_camera_zone_find_at
/// @description Best camera zone containing (_px,_py). Prefers non-default, then higher priority.
/// @param {Real} _px
/// @param {Real} _py
/// @param {Id.Instance} [_exclude] Zone to skip (usually the one just left)
/// @returns {Id.Instance}
function scr_camera_zone_find_at(_px, _py) {
    var _exclude = noone;
    if (argument_count > 2) _exclude = argument[2];

    var _best = noone;
    var _best_pri = -1000000;
    var _best_default = true;

    with (obj_camera_zone) {
        if (id == _exclude) continue;
        if (!point_in_rectangle(_px, _py, zone_min_x, zone_min_y, zone_max_x, zone_max_y)) continue;

        var _take = false;
        if (_best == noone) {
            _take = true;
        } else if (default_zone && !_best_default) {
            _take = false; // keep specialized
        } else if (!default_zone && _best_default) {
            _take = true;
        } else if (zone_priority > _best_pri) {
            _take = true;
        }

        if (_take) {
            _best = id;
            _best_pri = zone_priority;
            _best_default = default_zone;
        }
    }
    return _best;
}

/// @function scr_camera_death_view_locked
/// @description True while dissolve holds the camera (shake must not queue or tick here).
/// FADE_IN is unlocked so spawn play isn't frozen under the veil.
function scr_camera_death_view_locked() {
    if (!instance_exists(obj_player)) return false;
    with (obj_player) {
        if (!variable_instance_exists(id, "death_is_dissolve") || !death_is_dissolve) return false;
        if (!variable_instance_exists(id, "death_fade_phase")) return false;
        return (death_fade_phase == DEATH_SEQ.HOLD
            || death_fade_phase == DEATH_SEQ.FADE_OUT
            || death_fade_phase == DEATH_SEQ.BLACK);
    }
    return false;
}

/// @function scr_camera_trigger_shake
/// @param {Real} _mag Peak pixel offset
/// @param {Real} _dur Frames to shake
function scr_camera_trigger_shake(_mag, _dur) {
    if (!instance_exists(obj_camera_controller)) return;
    // Wall-kill sparks / late hit juice must not freeze under the death lock and replay on spawn.
    if (scr_camera_death_view_locked()) return;
    with (obj_camera_controller) {
        cam_shake_mag = max(cam_shake_mag, _mag);
        cam_shake_timer = max(cam_shake_timer, _dur);
    }
}

/// @function scr_camera_control
/// @description MMX-style zone bounds + border scroll; state-based look-ahead only (no anchor/lerp follow).
function scr_camera_control() {
    if (!instance_exists(obj_player)) exit;

    var _p = obj_player;
    // Hold the death view after dissolve starts; allow follow during the hurt wind-up.
    if (scr_camera_death_view_locked()) {
        // Drop any shake that began on the killing blow / wall slam so it can't resume after fade-in.
        scr_camera_clear_shake();
        // Keep parallax locked to the (possibly snapped) camera so tiles are ready under the fade.
        scr_parallax_update();
        exit;
    }

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

    var _look_mult = (variable_global_exists("camera_look_ahead_mult") ? global.camera_look_ahead_mult : 1);
    var _look_bonus = (variable_global_exists("camera_look_ahead_bonus") ? global.camera_look_ahead_bonus : 0);

    if (_wall_cling_cam) {
        cam_look_ahead = lerp(cam_look_ahead, 0, 0.18);
    } else if (global.hitstop <= 0) {
        // --- Look-ahead (state-based; zone mult/bonus for per-section framing) ---
        var _look_target = 0;
        var _look_speed = 0.12;
        var _face = (_p.last_direction != 0) ? _p.last_direction : sign(_p.image_xscale);
        if (_face == 0) _face = 1;

        if (_p.attacking) {
            _look_target = 90 * _face;
            _look_speed = 0.08;
        } else if (_p.is_sprinting) {
            _look_target = 130 * _face;
            _look_speed = 0.14;
        } else if (!_p.grounded) {
            _look_target = 100 * _face;
            _look_speed = 0.10;
        } else if (abs(_p.hsp) > 0.5) {
            _look_target = 120 * _face;
            _look_speed = 0.12;
        } else {
            _look_target = 40 * _face;
            _look_speed = 0.06;
        }

        _look_target = _look_target * _look_mult + _look_bonus * _face;
        // Cap by trailing-edge margin so the player never leaves the screen.
        // lower margin => more look-ahead (run-jump zone only sets this aggressively).
        var _trail = (variable_global_exists("camera_look_ahead_trail_margin")
            ? global.camera_look_ahead_trail_margin : 0.16);
        _trail = clamp(_trail, 0.08, 0.35);
        var _look_cap = max(40, cam_w * (0.5 - _trail));
        if (abs(_look_target) > _look_cap) _look_target = _look_cap * sign(_look_target);
        if (_look_mult > 1.01 || abs(_look_bonus) > 0.5) {
            _look_speed = max(_look_speed, 0.14);
        }
        cam_look_ahead = lerp(cam_look_ahead, _look_target, _look_speed);
        if (abs(cam_look_ahead) > _look_cap) {
            cam_look_ahead = _look_cap * sign(cam_look_ahead);
        }
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
        // Match player motion; never race ahead of them on look-ahead alone.
        if (_dx > 0.001) {
            _xspeed = max(_dx, global.camera_scroll_min_x);
        } else if (abs(_ox) > 0.5 && (_look_mult > 1.01 || abs(_look_bonus) > 0.5)) {
            // Soft settle into boosted framing while nearly still — keep it slow.
            _xspeed = global.camera_scroll_min_x;
        }
        if (_dy > 0.001) {
            _yspeed = max(_dy, global.camera_scroll_min_y);
        } else if (_p.grounded && abs(_oy) > 0.5) {
            // After descending, walking flat at spawn won't move _dy — still re-center view on foot Y.
            _yspeed = global.camera_scroll_min_y;
        }
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

    var _shake_x = 0;
    var _shake_y = 0;
    if (cam_shake_timer > 0) {
        cam_shake_timer--;
        _shake_x = random_range(-cam_shake_mag, cam_shake_mag);
        _shake_y = random_range(-cam_shake_mag, cam_shake_mag);
        if (cam_shake_timer <= 0) cam_shake_mag = 0;
    }

    camera_set_view_pos(cam, _new_x + _shake_x, _new_y + _shake_y);
    scr_parallax_update();
}
