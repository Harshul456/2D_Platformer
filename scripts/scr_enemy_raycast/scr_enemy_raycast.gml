/// @file scr_enemy_raycast.gml
/// @description Unified segment raycast — obj_solid instances + tilemap solids.

#macro ENEMY_RAYCAST_TILE_STEP 12

/// @function scr_enemy_raycast_tiles_along
/// @description Tile-only samples along a segment (obj_solid excluded).
function scr_enemy_raycast_tiles_along(_x1, _y1, _x2, _y2) {
    if (global.tilemap_collision_id == noone) return false;

    if (variable_instance_exists(id, "vsp") && variable_instance_exists(id, "shelf_bb_bottom_prev")) {
        tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);
    }

    var _dist = point_distance(_x1, _y1, _x2, _y2);
    if (_dist < 0.5) {
        return check_tile_collision(_x1, _y1);
    }

    var _step = ENEMY_RAYCAST_TILE_STEP;
    var _steps = max(1, ceil(_dist / _step));
    for (var _i = 0; _i <= _steps; _i++) {
        var _t = _i / _steps;
        if (check_tile_collision(lerp(_x1, _x2, _t), lerp(_y1, _y2, _t))) {
            return true;
        }
    }
    return false;
}

/// @function scr_enemy_raycast
/// @param {Real} _x1
/// @param {Real} _y1
/// @param {Real} _x2
/// @param {Real} _y2
/// @returns {Bool} True if segment is blocked by obj_solid or a solid tile.
function scr_enemy_raycast(_x1, _y1, _x2, _y2) {
    if (collision_line(_x1, _y1, _x2, _y2, obj_solid, true, true) != noone) {
        return true;
    }
    return scr_enemy_raycast_tiles_along(_x1, _y1, _x2, _y2);
}

/// @function scr_enemy_dual_los_clear
/// @description Chest + horizontal channel rays (avoids feet rays slicing through shared floor tiles).
/// @returns {Bool}
function scr_enemy_dual_los_clear() {
    if (!instance_exists(obj_player)) return false;

    var _ex = (bbox_left + bbox_right) * 0.5;
    var _ey = bbox_top + (bbox_bottom - bbox_top) * 0.35;
    var _px = (obj_player.bbox_left + obj_player.bbox_right) * 0.5;
    var _py = obj_player.bbox_top + (obj_player.bbox_bottom - obj_player.bbox_top) * 0.35;
    var _mid_y = (_ey + _py) * 0.5;

    // Horizontal channel — wall between actors on the same platform (does not graze floor).
    var _channel_clear = !scr_enemy_raycast_tiles_along(_ex, _mid_y, _px, _mid_y);
    if (!_channel_clear) return false;

    // Chest-height diagonal — blocks when player is on a different vertical band.
    var _chest_blocked = scr_enemy_raycast(_ex, _ey, _px, _py);
    return !_chest_blocked;
}
