/// @function scr_enemy_collision_tilemap
/// @returns {Id.Tilemap} Collision tilemap for this enemy instance.
function scr_enemy_collision_tilemap() {
    if (global.tilemap_collision_id != noone) return global.tilemap_collision_id;
    if (variable_instance_exists(id, "gnd_tilemap") && gnd_tilemap != -1 && gnd_tilemap != noone) {
        return gnd_tilemap;
    }
    return noone;
}

/// @function scr_enemy_place_on_standable_floor
/// @description Drop onto lay_collision (not background art). Room Y often lines up with visuals only.
/// @param {Real} [_max_drop] Max pixels to scan downward.
/// @returns {Bool} True if feet found standable support.
function scr_enemy_place_on_standable_floor(_max_drop) {
    if (argument_count < 1) _max_drop = 480;
    if (scr_enemy_collision_tilemap() == noone) return false;

    var _start_y = y;
    var _landed_y = noone;

    for (var _d = 0; _d <= _max_drop; _d++) {
        y = _start_y + _d;
        shelf_bb_bottom_prev = bbox_bottom;
        tilecol_sync_actor_context(0, shelf_bb_bottom_prev);
        if (scr_enemy_toes_have_standable_support()) {
            _landed_y = y;
            break;
        }
    }

    if (_landed_y == noone) {
        y = _start_y;
        return false;
    }

    // Un-embed if the downward scan sunk feet into the tile body.
    var _guard = 0;
    while (_guard++ < 24) {
        shelf_bb_bottom_prev = bbox_bottom;
        tilecol_sync_actor_context(0, shelf_bb_bottom_prev);
        var _fp = scr_enemy_foot_probes();
        if (!check_tile_collision(_fp.center, bbox_bottom)
            && !check_tile_collision(_fp.left, bbox_bottom)
            && !check_tile_collision(_fp.right, bbox_bottom)) {
            break;
        }
        y -= 1;
    }

    vsp = 0;
    enemy_grounded = scr_enemy_resolve_grounded();
    shelf_bb_bottom_prev = bbox_bottom;
    scr_enemy_floating_hover_sync_anchor();
    return true;
}

/// @function scr_enemy_snap_to_collision_floor
/// @description Create + Room Start — land on collision tiles, never on background-only art.
function scr_enemy_snap_to_collision_floor() {
    if (scr_enemy_collision_tilemap() == noone) return false;
    return scr_enemy_place_on_standable_floor(480);
}

/// @function scr_enemy_horizontal_lead_x
/// @description Symmetric horizontal probe anchor from instance x (immune to bbox asymmetry / sprite flip).
function scr_enemy_horizontal_lead_x(_h_step) {
    if (_h_step == 0) return x;
    var _half_w = (variable_instance_exists(id, "ENEMY_HMOVE_HALF_WIDTH") ? ENEMY_HMOVE_HALF_WIDTH : 14);
    return (_h_step > 0) ? floor(x + _half_w) : floor(x - _half_w);
}

/// @function scr_enemy_foot_probes
/// @description Narrow foot probes at spike tips — spr_enemy bbox is ~42px wide (shoulder wings) but feet are ~6px at center.
function scr_enemy_foot_probes() {
    var _cx = floor((bbox_left + bbox_right) * 0.5);
    var _hw = (variable_instance_exists(id, "ENEMY_FOOT_PROBE_HALF_WIDTH") ? ENEMY_FOOT_PROBE_HALF_WIDTH : 3);
    var _yoff = (variable_instance_exists(id, "ENEMY_FEET_Y_OFFSET") ? ENEMY_FEET_Y_OFFSET : 0);
    return {
        feet_y: floor(bbox_bottom) + _yoff,
        left: _cx - _hw,
        center: _cx,
        right: _cx + _hw
    };
}

/// @function scr_enemy_toes_have_standable_support
/// @description True when at least one foot spike hits standable floor (required on shelf caps 1/5/34/36).
function scr_enemy_toes_have_standable_support() {
    var _tm = global.tilemap_collision_id;
    if (_tm == noone) return false;
    var _gc = (variable_instance_exists(id, "ENEMY_GROUND_CHECK_DIST") ? ENEMY_GROUND_CHECK_DIST : 1);
    var _embed = (variable_instance_exists(id, "ENEMY_GROUND_STANDABLE_EMBED_PX") ? ENEMY_GROUND_STANDABLE_EMBED_PX : 10);
    var _fp = scr_enemy_foot_probes();
    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);
    return check_floor_standable(_fp.left, _fp.feet_y, _gc, _embed)
        || check_floor_standable(_fp.right, _fp.feet_y, _gc, _embed);
}

/// @function scr_enemy_on_shelf_cap_context
function scr_enemy_on_shelf_cap_context(_tm, _pl, _pc, _pr, _feet_y, _floor_probe_y) {
    if (_tm == noone) return false;
    if (tilemap_cell_thin_floor_near_feet(_tm, _pc, _feet_y)
        || tilemap_cell_thin_floor_near_feet(_tm, _pl, _feet_y)
        || tilemap_cell_thin_floor_near_feet(_tm, _pr, _feet_y)) return true;
    return tilemap_shelf_index_at_pixel(_tm, _pl, _floor_probe_y) != -1
        || tilemap_shelf_index_at_pixel(_tm, _pc, _floor_probe_y) != -1
        || tilemap_shelf_index_at_pixel(_tm, _pr, _floor_probe_y) != -1;
}

/// @function scr_enemy_resolve_grounded
/// @description Shelf-aware grounded (TileSet2 indices 1,5,34,35,36) — mirrors player §2 shelf rules.
function scr_enemy_resolve_grounded() {
    var _gc = (variable_instance_exists(id, "ENEMY_GROUND_CHECK_DIST") ? ENEMY_GROUND_CHECK_DIST : 1);
    var _inset = (variable_instance_exists(id, "ENEMY_GROUND_PROBE_EDGE_INSET") ? ENEMY_GROUND_PROBE_EDGE_INSET : 12);
    var _votes_min = (variable_instance_exists(id, "ENEMY_GROUND_LAND_VOTES_MIN_AIR") ? ENEMY_GROUND_LAND_VOTES_MIN_AIR : 2);
    var _vsp_max = (variable_instance_exists(id, "ENEMY_SHELF_STAND_VSP_ABS_MAX") ? ENEMY_SHELF_STAND_VSP_ABS_MAX : 3);
    var _vsp_tile1 = (variable_instance_exists(id, "ENEMY_SHELF_STAND_VSP_TILE1") ? ENEMY_SHELF_STAND_VSP_TILE1 : 1.15);
    var _embed = (variable_instance_exists(id, "ENEMY_GROUND_STANDABLE_EMBED_PX") ? ENEMY_GROUND_STANDABLE_EMBED_PX : 10);

    var _tm = global.tilemap_collision_id;
    if (_tm == noone) return false;

    var _fp = scr_enemy_foot_probes();
    var feet_y = _fp.feet_y;
    var p_left = _fp.left;
    var p_right = _fp.right;
    var p_center = _fp.center;
    var p_g_left = p_left;
    var p_g_right = p_right;

    var _floor_probe_y = feet_y + _gc;
    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);

    var _toe_l_stand = check_floor_standable(p_left, feet_y, _gc, _embed);
    var _toe_r_stand = check_floor_standable(p_right, feet_y, _gc, _embed);
    var _toe_stand = _toe_l_stand || _toe_r_stand;

    var _on_shelf = scr_enemy_on_shelf_cap_context(_tm, p_left, p_center, p_right, feet_y, _floor_probe_y);
    var _ix_l = tilemap_shelf_index_at_pixel(_tm, p_left, _floor_probe_y);
    var _ix_c = tilemap_shelf_index_at_pixel(_tm, p_center, _floor_probe_y);
    var _ix_r = tilemap_shelf_index_at_pixel(_tm, p_right, _floor_probe_y);
    var _shelf_strict_34_36 = (_ix_l == 34 || _ix_l == 36 || _ix_c == 34 || _ix_c == 36 || _ix_r == 34 || _ix_r == 36);
    var _shelf_touch_tile1 = (_ix_l == 1 || _ix_c == 1 || _ix_r == 1);

    var _vsp_toler = _vsp_max;
    if (_shelf_touch_tile1) _vsp_toler = min(_vsp_toler, _vsp_tile1);

    // Shelf caps: toe support only — center probe must not keep enemy hovering after knockback past lip.
    if (_on_shelf) {
        return (vsp >= 0) && _toe_stand && abs(vsp) <= _vsp_toler;
    }

    var _xl = p_g_left;
    var _xr = p_g_right;
    var touch_c = check_tile_collision(p_center, _floor_probe_y);
    var touch_l = check_tile_collision(_xl, _floor_probe_y);
    var touch_r = check_tile_collision(_xr, _floor_probe_y);
    var touch_any = touch_c || touch_l || touch_r;

    var _raw_n = (touch_c ? 1 : 0)
        + (check_tile_collision(p_left, _floor_probe_y) ? 1 : 0)
        + (check_tile_collision(p_right, _floor_probe_y) ? 1 : 0);
    var _toe = check_tile_collision(p_left, _floor_probe_y) || check_tile_collision(p_right, _floor_probe_y);
    var touch_floor = touch_any && (_raw_n >= _votes_min || (_raw_n >= 1 && _toe));

    var _stand_l = check_floor_standable(_xl, feet_y, _gc, _embed);
    var _stand_c = check_floor_standable(p_center, feet_y, _gc, _embed);
    var _stand_r = check_floor_standable(_xr, feet_y, _gc, _embed);
    var _stand_majority = ((_stand_l ? 1 : 0) + (_stand_c ? 1 : 0) + (_stand_r ? 1 : 0) >= _votes_min);

    return (vsp >= 0) && _stand_majority && touch_floor && _toe_stand;
}

/// @function scr_enemy_vertical_fall_step
/// @description One downward collision step while airborne (after lip detach / knockback).
function scr_enemy_vertical_fall_step(_tm, _fall_inset) {
    var _fp = scr_enemy_foot_probes();
    var p_left = _fp.left;
    var p_right = _fp.right;
    var p_center = _fp.center;
    var feet_y = _fp.feet_y;
    var _foot_probe_y = feet_y + 1;
    var _shelf_toes = tilemap_shelf_cap_under_toes(_tm, p_left, p_right, feet_y);
    var _col_clear;
    if (_shelf_toes) {
        _col_clear = !check_tile_collision(p_left, feet_y + 1, false, noone, false)
            && !check_tile_collision(p_center, feet_y + 1, false, noone, false)
            && !check_tile_collision(p_right, feet_y + 1, false, noone, false);
    } else {
        var _thin_row_ahead = tilemap_cell_thin_floor_tile(_tm, p_left, _foot_probe_y)
            || tilemap_cell_thin_floor_tile(_tm, p_center, _foot_probe_y)
            || tilemap_cell_thin_floor_tile(_tm, p_right, _foot_probe_y);
        if (_thin_row_ahead) {
            _col_clear = !check_tile_collision(p_left, _foot_probe_y, false, noone, true)
                && !check_tile_collision(p_center, _foot_probe_y, false, noone, true)
                && !check_tile_collision(p_right, _foot_probe_y, false, noone, true);
        } else {
            var _pl_fall = p_left;
            var _pr_fall = p_right;
            var _hil = check_tile_collision(_pl_fall, _foot_probe_y, false, noone, true);
            var _hir = check_tile_collision(_pr_fall, _foot_probe_y, false, noone, true);
            var _hic = check_tile_collision(p_center, _foot_probe_y, false, noone, true);
            _col_clear = !_hil && !_hic && !_hir;
            if (!_col_clear && !_hil && !_hir) _col_clear = true;
        }
    }
    if (_col_clear) {
        y += 1;
        enemy_grounded = false;
        return true;
    }
    var _led_snap = tilemap_ledge_down_snap_dy(_tm, p_left, p_center, p_right, feet_y + 1, bbox_bottom);
    if (_led_snap != noone) {
        y += _led_snap;
        vsp = 0;
        enemy_grounded = true;
        return false;
    }
    vsp = 0;
    return false;
}

/// @function scr_enemy_tile_movement
/// @description Tilemap collision for obj_enemy — player-equivalent shelf/edge rules (indices 1,5,34,35,36).
function scr_enemy_tile_movement() {
    var _tm = global.tilemap_collision_id;
    var _ledge_win = (variable_instance_exists(id, "ENEMY_HORIZONTAL_LEDGE_WINDOW_PX")
        ? ENEMY_HORIZONTAL_LEDGE_WINDOW_PX : 6);
    var _wall_head_off = (variable_instance_exists(id, "ENEMY_WALL_CHECK_OFFSET")
        ? ENEMY_WALL_CHECK_OFFSET : 4);
    var _toe_inset = (variable_instance_exists(id, "ENEMY_LEDGE_TOE_INSET")
        ? ENEMY_LEDGE_TOE_INSET : 2);
    var _fall_inset = (variable_instance_exists(id, "ENEMY_AIR_FALL_EDGE_INSET")
        ? ENEMY_AIR_FALL_EDGE_INSET : 18);
    var _probe_inset = (variable_instance_exists(id, "ENEMY_GROUND_PROBE_EDGE_INSET")
        ? ENEMY_GROUND_PROBE_EDGE_INSET : 12);
    _fall_inset = max(_fall_inset, _probe_inset);

    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);

    if (_tm == noone) {
        x += hsp;
        y += vsp;
        shelf_bb_bottom_prev = bbox_bottom;
        enemy_grounded = false;
        return;
    }

    var _fp = scr_enemy_foot_probes();
    var p_left   = _fp.left;
    var p_right  = _fp.right;
    var p_center = _fp.center;
    var feet_y   = _fp.feet_y;
    var head_y   = floor(bbox_top);
    var center_y = floor((bbox_top + bbox_bottom) * 0.5);

    // One-way shelf threshold land (falling onto ledge caps)
    if (vsp > 0) {
        var _mag = sign(hsp);
        var _snap = tilemap_shelf_threshold_land_dy(_tm, p_left, p_center, p_right, bbox_bottom,
            shelf_bb_bottom_prev, vsp, _mag);
        if (_snap != noone) {
            y += _snap;
            vsp = 0;
            enemy_grounded = true;
            _fp = scr_enemy_foot_probes();
            feet_y = _fp.feet_y;
            head_y = floor(bbox_top);
            center_y = floor((bbox_top + bbox_bottom) * 0.5);
            p_left = _fp.left;
            p_right = _fp.right;
            p_center = _fp.center;
        }
    }

    // --- Horizontal (player-equivalent ledge-window side probes) ---
    if (hsp != 0) {
        if (variable_instance_exists(id, "enemy_hmove_blocked")) enemy_hmove_blocked = false;
        var _h_step = sign(hsp);
        var _bb_bot = bbox_bottom;
        // ceil(-0.85) == 0 in GML — must ceil abs(speed) or leftward sub-1px speeds never step.
        repeat (ceil(abs(hsp))) {
            feet_y = floor(bbox_bottom);
            head_y = floor(bbox_top);
            center_y = floor((bbox_top + bbox_bottom) * 0.5);

            var _target_side = (_h_step > 0) ? floor(bbox_right) : floor(bbox_left);
            var _wx = _target_side + _h_step;
            var _y_h = head_y + _wall_head_off;
            var _y_t = feet_y - _toe_inset;
            var _use_head = !(variable_instance_exists(id, "ENEMY_HMOVE_USE_HEAD_PROBE") && !ENEMY_HMOVE_USE_HEAD_PROBE);

            var _ledge_y_a = _use_head ? min(_y_h, center_y, _y_t) : min(center_y, _y_t);
            var _ledge_y_b = _use_head ? max(_y_h, center_y, _y_t) : max(center_y, _y_t);
            var _ledge_mount = tilemap_horizontal_ledge_mount_priority(_tm, _wx, _bb_bot, _ledge_y_a, _ledge_y_b, _ledge_win);
            var _air_fb_face = (!enemy_grounded) && (
                (_use_head && tilemap_horizontal_full_block_side_face_at(_tm, _wx, _y_h, _bb_bot, _ledge_win)) ||
                tilemap_horizontal_full_block_side_face_at(_tm, _wx, center_y, _bb_bot, _ledge_win) ||
                tilemap_horizontal_full_block_side_face_at(_tm, _wx, _y_t, _bb_bot, _ledge_win));

            if (_ledge_mount && !_air_fb_face) {
                x += _h_step;
            } else {
                var _blk_h = _use_head && tilemap_horizontal_side_probe_blocks(_tm, _wx, _y_h, _bb_bot, _ledge_win);
                var _blk_c = tilemap_horizontal_side_probe_blocks(_tm, _wx, center_y, _bb_bot, _ledge_win);
                var _blk_t = enemy_grounded
                    && tilemap_horizontal_side_probe_blocks(_tm, _wx, _y_t, _bb_bot, _ledge_win);
                var _clear = (!_blk_h && !_blk_c && !_blk_t);
                if (_air_fb_face) _clear = false;

                if (variable_instance_exists(id, "enemy_hmove_blocked")) {
                    enemy_hmove_blocked = !_clear;
                }

                if (_clear) {
                    x += _h_step;
                } else {
                    hsp = 0;
                    if (!(variable_instance_exists(id, "state") && state == ENEMY_STATE.STUNNED)) {
                        knockbackX = 0;
                    }
                    break;
                }
            }
        }
    }

    // Re-sample grounded after horizontal (knockback off 34/36 lips must drop same frame).
    enemy_grounded = scr_enemy_resolve_grounded();
    if (enemy_grounded && !scr_enemy_toes_have_standable_support()) {
        enemy_grounded = false;
    }
    _fp = scr_enemy_foot_probes();
    feet_y = _fp.feet_y;
    head_y = floor(bbox_top);
    p_left = _fp.left;
    p_right = _fp.right;
    p_center = _fp.center;

    // --- Vertical (player §6 branches: airborne fall vs grounded / shelf-cap) ---
    if (vsp != 0) {
        var _v_step = sign(vsp);
        repeat (ceil(abs(vsp))) {
            _fp = scr_enemy_foot_probes();
            feet_y = _fp.feet_y;
            head_y = floor(bbox_top);
            p_left = _fp.left;
            p_right = _fp.right;
            p_center = _fp.center;

            if (enemy_grounded && !scr_enemy_toes_have_standable_support()) {
                enemy_grounded = false;
            }

            var _col_clear;
            if (!enemy_grounded && _v_step > 0) {
                var _foot_probe_y = feet_y + _v_step;
                var _shelf_toes = tilemap_shelf_cap_under_toes(_tm, p_left, p_right, feet_y);
                if (_shelf_toes) {
                    _col_clear = !check_tile_collision(p_left, feet_y + _v_step, false, noone, false)
                        && !check_tile_collision(p_center, feet_y + _v_step, false, noone, false)
                        && !check_tile_collision(p_right, feet_y + _v_step, false, noone, false);
                } else {
                    var _thin_row_ahead = tilemap_cell_thin_floor_tile(_tm, p_left, _foot_probe_y)
                        || tilemap_cell_thin_floor_tile(_tm, p_center, _foot_probe_y)
                        || tilemap_cell_thin_floor_tile(_tm, p_right, _foot_probe_y);
                    if (_thin_row_ahead) {
                        _col_clear = !check_tile_collision(p_left, _foot_probe_y, false, noone, true)
                            && !check_tile_collision(p_center, _foot_probe_y, false, noone, true)
                            && !check_tile_collision(p_right, _foot_probe_y, false, noone, true);
                    } else {
                        var _pl_fall = p_left;
                        var _pr_fall = p_right;
                        var _hil = check_tile_collision(_pl_fall, _foot_probe_y, false, noone, true);
                        var _hir = check_tile_collision(_pr_fall, _foot_probe_y, false, noone, true);
                        var _hic = check_tile_collision(p_center, _foot_probe_y, false, noone, true);
                        _col_clear = !_hil && !_hic && !_hir;
                        if (!_col_clear && !_hil && !_hir) {
                            _col_clear = true;
                        }
                    }
                }
            } else {
                var _rise_tile = (_v_step < 0);
                if (_v_step > 0) {
                    var _shelf_toes_g = tilemap_shelf_cap_under_toes(_tm, p_left, p_right, feet_y);
                    var _ig_shelf_down = !enemy_grounded && !_shelf_toes_g;
                    _col_clear = !check_tile_collision(p_left, feet_y + _v_step, false, noone, _ig_shelf_down)
                        && !check_tile_collision(p_center, feet_y + _v_step, false, noone, _ig_shelf_down)
                        && !check_tile_collision(p_right, feet_y + _v_step, false, noone, _ig_shelf_down);
                } else {
                    var _check_y = head_y;
                    _col_clear = !check_tile_collision(p_left, _check_y + _v_step, _rise_tile, feet_y)
                        && !check_tile_collision(p_center, _check_y + _v_step, _rise_tile, feet_y)
                        && !check_tile_collision(p_right, _check_y + _v_step, _rise_tile, feet_y);
                }
            }

            if (_col_clear) {
                y += _v_step;
                enemy_grounded = false;
            } else {
                if (_v_step > 0) {
                    var _led_snap = tilemap_ledge_down_snap_dy(_tm, p_left, p_center, p_right,
                        feet_y + _v_step, bbox_bottom);
                    if (_led_snap != noone) {
                        y += _led_snap;
                        vsp = 0;
                        enemy_grounded = true;
                    } else {
                        vsp = 0;
                    }
                } else {
                    vsp = 0;
                }
                break;
            }
        }
        if (vsp > 0 && enemy_grounded) vsp = 0;
    }

    enemy_grounded = scr_enemy_resolve_grounded();
    // Lip knockback with vsp≈0 skips the vertical loop — seed gravity and fall same frame.
    if (!enemy_grounded && vsp <= 0.001) {
        vsp = grv;
        var _fall_steps = max(1, ceil(vsp));
        repeat (_fall_steps) {
            if (enemy_grounded) break;
            if (!scr_enemy_vertical_fall_step(_tm, _fall_inset)) break;
        }
    }

    shelf_bb_bottom_prev = bbox_bottom;
}
