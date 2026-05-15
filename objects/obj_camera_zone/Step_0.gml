/// MMX obj_camera_set — switch active scroll box when player enters this zone.
if (!instance_exists(obj_player)) exit;

var _px = obj_player.x;
var _py = obj_player.y;

if (global.camera_current_zone != id) {
    var _activate = false;
    if (global.camera_current_zone == -1 && default_zone) _activate = true;
    else if (point_in_rectangle(_px, _py, zone_min_x, zone_min_y, zone_max_x, zone_max_y)) _activate = true;

    if (_activate) {
        global.camera_current_zone = id;
        global.camera_min_x = zone_min_x;
        global.camera_min_y = zone_min_y;
        global.camera_max_x = zone_max_x;
        global.camera_max_y = zone_max_y;
        if (zone_apply_vbor) {
            global.camera_vbor_min_y = zone_vbor_min_y;
            global.camera_vbor_max_y = zone_vbor_max_y;
        }
    }
}
