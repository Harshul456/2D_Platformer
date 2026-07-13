/// @file scr_enemy_ai_patrol_core.gml
/// @description PATROL ↔ CHASE core loop with unified dual-raycast aggro drop (HK height/flee rules).

#macro ENEMY_LOST_LOS_DROP_FRAMES 40

/// @function scr_enemy_patrol_leash_bounds
function scr_enemy_patrol_leash_bounds() {
    var _home = variable_instance_exists(id, "home_x") ? home_x : x;
    var _half = variable_instance_exists(id, "patrol_range_px") ? patrol_range_px : 180;
    var _margin = 24;
    return {
        left: max(_margin, _home - _half),
        right: min(room_width - _margin, _home + _half)
    };
}

/// @function scr_enemy_patrol_floor_ahead
/// @description Forward foot probes below the leading toe (matches pre-raycast shelf/ledge logic).
function scr_enemy_patrol_floor_ahead(_dir) {
    if (_dir == 0) return false;
    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);
    var _feet = bbox_bottom;
    var _h = sign(_dir);
    var _lead = scr_enemy_horizontal_lead_x(_h);
    var _near = check_tile_collision(_lead, _feet + 1) || check_tile_collision(_lead, _feet + 4);
    var _dx = _dir * 14;
    var _diag = check_tile_collision(_lead + _dx, _feet + 10)
        || check_tile_collision(_lead + _dx * 0.5, _feet + 6);
    return _near || _diag;
}

/// @function scr_enemy_patrol_wall_ahead
/// @description Leading-edge side probes (ledge-window aware — same as tile movement).
function scr_enemy_patrol_wall_ahead(_dir) {
    if (_dir == 0) return false;

    var _h_step = sign(_dir);
    var _wx = scr_enemy_horizontal_lead_x(_h_step) + _h_step;
    var _bb_bot = bbox_bottom;
    var _head_y = floor(bbox_top);
    var _center_y = floor((bbox_top + bbox_bottom) * 0.5);
    var _fp = scr_enemy_foot_probes();
    var _feet_y = _fp.feet_y;
    var _ledge_win = (variable_instance_exists(id, "ENEMY_HORIZONTAL_LEDGE_WINDOW_PX")
        ? ENEMY_HORIZONTAL_LEDGE_WINDOW_PX : 6);
    var _head_off = (variable_instance_exists(id, "ENEMY_WALL_CHECK_OFFSET")
        ? ENEMY_WALL_CHECK_OFFSET : 4);
    var _toe_inset = (variable_instance_exists(id, "ENEMY_LEDGE_TOE_INSET")
        ? ENEMY_LEDGE_TOE_INSET : 2);
    var _y_h = _head_y + _head_off;
    var _y_t = _feet_y - _toe_inset;

    if (collision_line(
        (_h_step > 0) ? bbox_right : bbox_left, _center_y,
        (_h_step > 0) ? bbox_right + _h_step * 14 : bbox_left + _h_step * 14, _center_y,
        obj_solid, true, true) != noone) {
        return true;
    }

    var _tm = global.tilemap_collision_id;
    if (_tm == noone) return false;

    return tilemap_horizontal_side_probe_blocks(_tm, _wx, _y_h, _bb_bot, _ledge_win)
        || tilemap_horizontal_side_probe_blocks(_tm, _wx, _center_y, _bb_bot, _ledge_win)
        || tilemap_horizontal_side_probe_blocks(_tm, _wx, _y_t, _bb_bot, _ledge_win);
}

/// @function scr_enemy_patrol_flip
function scr_enemy_patrol_flip() {
    patrol_dir *= -1;
    scr_enemy_set_facing(patrol_dir);
}

/// @function scr_enemy_patrol_drop_aggro
/// @description Re-anchor leash at current X and return to PATROL after sustained broken tracking.
/// @param {Real} [_patrol_dir] Optional patrol direction after drop (e.g. away from a dead-end wall).
function scr_enemy_patrol_drop_aggro(_patrol_dir) {
    home_x = x;
    spawn_x = home_x;
    lost_los_timer = 0;
    chase_path_blocked_timer = 0;
    chase_wall_stuck_timer = 0;
    patrol_flip_cooldown = 0;
    chase_reaggro_cooldown = 0;
    hsp = 0;
    state = ENEMY_STATE.PATROL;
    image_blend = c_white;
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;
    if (!is_undefined(_patrol_dir) && _patrol_dir != 0) {
        patrol_dir = sign(_patrol_dir);
        scr_enemy_set_facing(patrol_dir);
    }
}

/// @function scr_enemy_ai_patrol_core
/// @description Runs PATROL or CHASE movement + dual-raycast aggro acquire/drop. Call from scr_enemy_ai.
function scr_enemy_ai_patrol_core() {
    if (!instance_exists(obj_player)) {
        if (state == ENEMY_STATE.CHASE || state == ENEMY_STATE.NOTICE) scr_enemy_patrol_drop_aggro();
        else hsp = 0;
        return;
    }

    var _dist_total = point_distance(x, y, obj_player.x, obj_player.y);
    var _los_clear = scr_enemy_dual_los_clear();

    if (variable_instance_exists(id, "chase_reaggro_cooldown") && chase_reaggro_cooldown > 0) {
        chase_reaggro_cooldown--;
    }

    switch (state) {
        case ENEMY_STATE.PATROL: {
            image_yscale = base_yscale;
            image_blend = c_white;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            // Spot player → threat reaction (freeze + blue alert) before chase commit.
            if (_dist_total < chaseRange && _los_clear && chase_reaggro_cooldown <= 0) {
                scr_enemy_begin_notice();
                break;
            }

            // Walk on leash — tile movement handles walls/ledges; flip on stall in Step.
            var _bounds = scr_enemy_patrol_leash_bounds();
            hsp = moveSpeed * patrol_dir;
            scr_enemy_set_facing(patrol_dir);

            if (x <= _bounds.left + 2) {
                patrol_dir = 1;
                x = max(x, _bounds.left);
                scr_enemy_set_facing(1);
            } else if (x >= _bounds.right - 2) {
                patrol_dir = -1;
                x = min(x, _bounds.right);
                scr_enemy_set_facing(-1);
            }
        } break;

        case ENEMY_STATE.CHASE: {
            image_yscale = base_yscale;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            var _dir = scr_enemy_dir_toward_player();
            if (_dir != 0) scr_enemy_set_facing(_dir);

            var _too_far = (_dist_total > chaseRange * 1.2);
            var _los_blocked = !_los_clear;

            if (_too_far) {
                lost_los_timer++;
                if (lost_los_timer >= ENEMY_LOST_LOS_DROP_FRAMES) {
                    scr_enemy_patrol_drop_aggro();
                    break;
                }
                hsp = 0;
                break;
            }

            if (_los_blocked) {
                lost_los_timer++;
                if (lost_los_timer >= ENEMY_LOST_LOS_DROP_FRAMES) {
                    scr_enemy_patrol_drop_aggro();
                    break;
                }
            } else {
                lost_los_timer = 0;
            }

            // Always close horizontally — tile movement resolves walls (no asymmetric wall-ray gate).
            if (_dir != 0) {
                hsp = moveSpeed * _dir;
                // Player on a higher ledge — don't keep walking into the wall underneath them.
                if (scr_enemy_player_above_unreachable() && scr_enemy_patrol_wall_ahead(_dir)) {
                    hsp = 0;
                }
            } else {
                hsp = 0;
            }

            // Player on a lower ledge — fall/step down instead of hovering stuck above them.
            if (instance_exists(obj_player) && obj_player.bbox_bottom > bbox_bottom + 10) {
                vsp = max(vsp, moveSpeed);
            }
        } break;
    }
}
