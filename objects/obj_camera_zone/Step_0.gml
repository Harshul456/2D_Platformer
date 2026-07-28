/// MMX-style camera zones — enter to activate; non-default preferred over full-room default.
if (!instance_exists(obj_player)) exit;

var _px = obj_player.x;
var _py = obj_player.y;
var _inside = point_in_rectangle(_px, _py, zone_min_x, zone_min_y, zone_max_x, zone_max_y);

// Still the active zone: if player left, find a replacement (don't let full-room default steal mid-cue).
if (global.camera_current_zone == id) {
    if (!_inside) {
        var _next = scr_camera_zone_find_at(_px, _py, id);
        if (_next != noone) {
            with (_next) scr_camera_zone_activate();
        }
    }
    exit;
}

// Not active — try to become active.
var _activate = false;
if (global.camera_current_zone == -1 && default_zone) {
    _activate = true;
} else if (_inside && !default_zone) {
    // Prefer this zone if nothing active, or if higher priority than current non-containing zone,
    // or if current is default and we're a specialized cue.
    if (global.camera_current_zone == -1) {
        _activate = true;
    } else if (instance_exists(global.camera_current_zone)) {
        var _cur = global.camera_current_zone;
        var _cur_inside = point_in_rectangle(_px, _py, _cur.zone_min_x, _cur.zone_min_y, _cur.zone_max_x, _cur.zone_max_y);
        if (!_cur_inside) {
            _activate = true;
        } else if (_cur.default_zone && !default_zone) {
            _activate = true;
        } else if (zone_priority > _cur.zone_priority) {
            _activate = true;
        }
    } else {
        _activate = true;
    }
}

if (_activate) {
    scr_camera_zone_activate();
}
