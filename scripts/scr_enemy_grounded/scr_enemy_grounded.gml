/// @file scr_enemy_grounded.gml
/// @description Grounded FSM for obj_enemy_parent using **tilemap** collision (no place_meeting / obj_wall).
///             Ledge / partial tiles: configure `TILECOL_*` macros in `check_tile_collision.gml`.
///             Call scr_enemy_grounded_step() once per Step — gravity + vertical resolve run inside it.
///
/// Instance variables (obj_enemy_parent Create):
///   gnd_tilemap — from layer_tilemap_get_id(layer_get_id("Collisions")); falls back to global.tilemap_collision_id
///   gnd_state, move_speed, sight_range, gnd_facing, gnd_eye_x, gnd_eye_y,
///   attack_range — max horizontal gap (px) between bbox edges to start ATTACK (see scr_enemy_grounded_melee_in_attack_range),
///   gnd_attack_vertical_overlap_min — min vertical bbox overlap (px) required for melee (default 10),
///   gnd_patrol_x1, gnd_patrol_x2 — horizontal leash while patrolling (re-centered when chase ends; see scr_enemy_grounded_patrol_reanchor_here),
///   gnd_patrol_half_width — half-width used when re-anchoring (default 140),
///   gnd_attack_duration, gnd_attack_lunge, gnd_attack_lunge_frames,
///   gnd_hurt_stun_frames, gnd_hurt_stun_timer, gnd_knock_h, gnd_hp, gnd_hurt_knockback_h, hit_blink_timer,
///   gnd_touch_damage, gnd_touch_damage_patrol / _chase / _attack — touch damage vs player (optional),
///   gnd_touch_stun_frames — if > 0, overrides ENEMY_STUN_FRAMES on touch,
///   gnd_touch_knock_x, gnd_touch_knock_y — touch knockback (optional; else player ENEMY_KNOCKBACK_*),
///   grav, vsp,
///   gnd_los_sample_px — spacing along LOS ray for tile samples (default 6),
///   gnd_ledge_forward_px — horizontal offset for ledge probe (default ~half 64px width + margin; raise for wider sprites),
///   gnd_foot_inset — px trimmed from bbox bottom for side/body tile tests (default 12 for 64×64),
///   vsp_max_fall — max downward speed per step (default 14) to reduce thin-floor tunneling.

#macro GND_STATE_PATROL   0
#macro GND_STATE_CHASE    1
#macro GND_STATE_ATTACK   2
#macro GND_STATE_DAMAGED  3
#macro GND_STATE_DEAD     4

/// @function scr_enemy_grounded_get_tm
function scr_enemy_grounded_get_tm() {
    var tm = variable_instance_exists(id, "gnd_tilemap") ? gnd_tilemap : noone;
    if (tm == -1 || tm == noone) tm = global.tilemap_collision_id;
    return tm;
}

/// @function scr_enemy_grounded_tile_solid_pixel
function scr_enemy_grounded_tile_solid_pixel(_tm, _px, _py) {
    if (_tm == -1 || _tm == noone) return false;
    return tilemap_point_solid(_tm, _px, _py);
}

/// @function scr_enemy_grounded_body_foot_inset
function scr_enemy_grounded_body_foot_inset() {
    return variable_instance_exists(id, "gnd_foot_inset") ? gnd_foot_inset : 12;
}

/// @function scr_enemy_grounded_body_bbox_tile_overlap
/// @description Solid tiles overlapping bbox excluding lowest strip (feet band) so floor tiles are not walls.
function scr_enemy_grounded_body_bbox_tile_overlap(_tm, _x, _y) {
    if (_tm == -1 || _tm == noone) return false;
    var inset = scr_enemy_grounded_body_foot_inset();
    var spr = sprite_index;
    var ox = sprite_get_xoffset(spr);
    var oy = sprite_get_yoffset(spr);
    var L = _x - ox + sprite_get_bbox_left(spr);
    var R = _x - ox + sprite_get_bbox_right(spr);
    var T = _y - oy + sprite_get_bbox_top(spr);
    var B = _y - oy + sprite_get_bbox_bottom(spr) - inset;
    if (B <= T + 2) return false;
    return tilemap_bbox_overlaps_solid(_tm, L, T, R, B);
}

/// @function scr_enemy_grounded_feet_bottom_in_solids
/// @description True if the sprite bottom pixel row sits in a solid tile (vertical landing).
function scr_enemy_grounded_feet_bottom_in_solids(_tm, _x, _y) {
    if (_tm == -1 || _tm == noone) return false;
    var spr = sprite_index;
    var ox = sprite_get_xoffset(spr);
    var oy = sprite_get_yoffset(spr);
    var bl = _x - ox + sprite_get_bbox_left(spr) + 2;
    var br = _x - ox + sprite_get_bbox_right(spr) - 2;
    var bb = _y - oy + sprite_get_bbox_bottom(spr);
    return tilemap_point_solid(_tm, bl, bb) || tilemap_point_solid(_tm, br, bb)
        || tilemap_point_solid(_tm, (bl + br) * 0.5, bb);
}

/// @function scr_enemy_grounded_head_blocked
function scr_enemy_grounded_head_blocked(_tm, _x, _y) {
    if (_tm == -1 || _tm == noone) return false;
    var spr = sprite_index;
    var ox = sprite_get_xoffset(spr);
    var oy = sprite_get_yoffset(spr);
    var bt = _y - oy + sprite_get_bbox_top(spr);
    var mx = _x - ox + (sprite_get_bbox_left(spr) + sprite_get_bbox_right(spr)) * 0.5;
    return tilemap_point_solid(_tm, mx, bt) || tilemap_point_solid(_tm, mx, bt - 1);
}

/// @function scr_enemy_grounded_core_center_in_solid
function scr_enemy_grounded_core_center_in_solid(_tm, _x, _y) {
    if (_tm == -1 || _tm == noone) return false;
    var spr = sprite_index;
    var ox = sprite_get_xoffset(spr);
    var oy = sprite_get_yoffset(spr);
    var mx = _x - ox + (sprite_get_bbox_left(spr) + sprite_get_bbox_right(spr)) * 0.5;
    var my = _y - oy + (sprite_get_bbox_top(spr) + sprite_get_bbox_bottom(spr)) * 0.5;
    return tilemap_point_solid(_tm, mx, my);
}

/// @function scr_enemy_grounded_snap_out_of_tiles
/// @description Nudge out of embedded solids (spawn / knockback): core center inside a tile.
function scr_enemy_grounded_snap_out_of_tiles(_tm) {
    if (_tm == -1 || _tm == noone) return;
    var guard = 0;
    while (scr_enemy_grounded_core_center_in_solid(_tm, x, y) && guard < 128) {
        y -= 1;
        guard++;
    }
}

/// @function scr_enemy_grounded_move_x_pixels
function scr_enemy_grounded_move_x_pixels(_tm, _dx) {
    if (_dx == 0) return;
    var s = sign(_dx);
    var n = ceil(abs(_dx));
    if (_tm == -1 || _tm == noone) {
        x += _dx;
        return;
    }
    repeat (n) {
        if (!scr_enemy_grounded_body_bbox_tile_overlap(_tm, x + s, y)) {
            x += s;
        } else {
            break;
        }
    }
}

/// @function scr_enemy_grounded_move_y_pixels
function scr_enemy_grounded_move_y_pixels(_tm, _dy) {
    if (_dy == 0) return;
    var s = sign(_dy);
    var n = ceil(abs(_dy));
    if (_tm == -1 || _tm == noone) {
        y += _dy;
        return;
    }
    repeat (n) {
        var ny = y + s;
        if (s > 0) {
            if (!scr_enemy_grounded_feet_bottom_in_solids(_tm, x, ny)) {
                y = ny;
            } else {
                scr_enemy_grounded_snap_feet_to_tile_top(_tm);
                vsp = 0;
                break;
            }
        } else {
            if (!scr_enemy_grounded_head_blocked(_tm, x, ny)) {
                y = ny;
            } else {
                vsp = 0;
                break;
            }
        }
    }
}

/// @function scr_enemy_grounded_snap_feet_to_tile_top
/// @description After landing probe hits solid, step up until the feet row clears tile interiors.
function scr_enemy_grounded_snap_feet_to_tile_top(_tm) {
    if (_tm == -1 || _tm == noone) return;
    var guard = 0;
    while (scr_enemy_grounded_feet_bottom_in_solids(_tm, x, y) && guard++ < 64) {
        y -= 1;
    }
}

/// @function scr_enemy_grounded_tile_line_blocked
/// @description Samples along segment (x1,y1)→(x2,y2) for solid tiles.
function scr_enemy_grounded_tile_line_blocked(_tm, _x1, _y1, _x2, _y2) {
    if (_tm == -1 || _tm == noone) return false;
    var dist = point_distance(_x1, _y1, _x2, _y2);
    var step = variable_instance_exists(id, "gnd_los_sample_px") ? gnd_los_sample_px : 6;
    step = max(2, step);
    var steps = max(2, ceil(dist / step));
    for (var i = 0; i <= steps; i++) {
        var t = i / steps;
        var sx = lerp(_x1, _x2, t);
        var sy = lerp(_y1, _y2, t);
        if (tilemap_point_solid(_tm, sx, sy)) return true;
    }
    return false;
}

/// @function scr_enemy_grounded_facing_sign
function scr_enemy_grounded_facing_sign() {
    if (variable_instance_exists(id, "gnd_facing") && gnd_facing != 0) return sign(gnd_facing);
    var s = sign(image_xscale);
    return (s != 0) ? s : 1;
}

/// @function scr_enemy_grounded_eye_xy
function scr_enemy_grounded_eye_xy() {
    var _ex = variable_instance_exists(id, "gnd_eye_x") ? gnd_eye_x : 20;
    var _ey = variable_instance_exists(id, "gnd_eye_y") ? gnd_eye_y : -24;
    var _f = scr_enemy_grounded_facing_sign();
    return { x: x + _ex * _f, y: y + _ey };
}

/// @function scr_enemy_grounded_segment_hits_player_bbox
/// @description Fallback when collision_line misses: sample segment against obj_player bbox (expanded).
function scr_enemy_grounded_segment_hits_player_bbox(_x1, _y1, _x2, _y2) {
    if (!instance_exists(obj_player)) return false;
    var pad = 8;
    var L = obj_player.bbox_left - pad;
    var R = obj_player.bbox_right + pad;
    var T = obj_player.bbox_top - pad;
    var B = obj_player.bbox_bottom + pad;
    var dist = point_distance(_x1, _y1, _x2, _y2);
    var steps = max(3, ceil(dist / 12));
    for (var i = 0; i <= steps; i++) {
        var t = i / steps;
        var sx = lerp(_x1, _x2, t);
        var sy = lerp(_y1, _y2, t);
        if (point_in_rectangle(sx, sy, L, T, R, B)) return true;
    }
    return false;
}

/// @function scr_enemy_grounded_can_see_player
/// @description LOS: tile check uses a mostly-horizontal ray at chest height so the ray does not
///              slice through the floor you are both standing on (diagonal tile samples always hit ground).
///              Then object visibility (collision_line or bbox segment fallback).
function scr_enemy_grounded_can_see_player() {
    if (!instance_exists(obj_player)) return false;
    var _eye = scr_enemy_grounded_eye_xy();
    var _px = obj_player.x;
    var _py = obj_player.y;
    if (point_distance(_eye.x, _eye.y, _px, _py) > sight_range) return false;
    var _tm = scr_enemy_grounded_get_tm();
    if (_tm != -1 && _tm != noone) {
        var _ty = bbox_top + (bbox_bottom - bbox_top) * 0.35;
        var _pty = obj_player.bbox_top + (obj_player.bbox_bottom - obj_player.bbox_top) * 0.35;
        var _mid_y = (_ty + _pty) * 0.5;
        if (scr_enemy_grounded_tile_line_blocked(_tm, _eye.x, _mid_y, _px, _mid_y)) return false;
    }
    if (collision_line(_eye.x, _eye.y, _px, _py, obj_player, false, true) == noone) {
        if (!scr_enemy_grounded_segment_hits_player_bbox(_eye.x, _eye.y, _px, _py)) return false;
    }
    return true;
}

/// @function scr_enemy_grounded_floor_or_ledge_ahead
/// @description tilemap_get_at_pixel forward + at feet (and spec: x + offset*facing, y + 1).
function scr_enemy_grounded_floor_or_ledge_ahead(_dir) {
    if (_dir == 0) return true;
    var _tm = scr_enemy_grounded_get_tm();
    if (_tm == -1 || _tm == noone) return true;
    var f = sign(_dir);
    var ox = variable_instance_exists(id, "gnd_ledge_forward_px") ? gnd_ledge_forward_px : 34;
    var px1 = x + ox * f;
    var py_feet = bbox_bottom + 1;
    if (tilemap_point_solid(_tm, px1, py_feet)) return true;
    if (tilemap_point_solid(_tm, x + ox * f, y + 1)) return true;
    return false;
}

/// @function scr_enemy_grounded_wall_blocking_h
/// @description Samples several heights along the leading vertical edge (works for tall / 64px sprites).
function scr_enemy_grounded_wall_blocking_h(_dir) {
    if (_dir == 0) return false;
    var _tm = scr_enemy_grounded_get_tm();
    if (_tm == -1 || _tm == noone) return false;
    var s = sign(_dir);
    var px = (s > 0) ? bbox_right + s : bbox_left + s;
    var bh = bbox_bottom - bbox_top;
    if (bh < 8) bh = 8;
    for (var i = 0; i < 5; i++) {
        var t = 0.08 + i * 0.21;
        var yy = bbox_top + bh * t;
        if (scr_enemy_grounded_tile_solid_pixel(_tm, px, yy)) return true;
    }
    return false;
}

/// @function scr_enemy_grounded_apply_hmove
function scr_enemy_grounded_apply_hmove(_hsp) {
    var _tm = scr_enemy_grounded_get_tm();
    if (_hsp != 0) {
        var sgn = sign(_hsp);
        image_xscale = abs(image_xscale) * sgn;
        gnd_facing = sgn;
    }
    scr_enemy_grounded_move_x_pixels(_tm, _hsp);
}

/// @function scr_enemy_grounded_physics_gravity_vertical
function scr_enemy_grounded_physics_gravity_vertical() {
    var _tm = scr_enemy_grounded_get_tm();
    vsp += grav;
    var cap = 14;
    if (variable_instance_exists(id, "vsp_max_fall")) cap = vsp_max_fall;
    vsp = min(vsp, cap);
    scr_enemy_grounded_move_y_pixels(_tm, vsp);
    scr_enemy_grounded_snap_out_of_tiles(_tm);
}

/// @function scr_enemy_grounded_patrol_reanchor_here
/// @description Re-centers patrol leash on current X so giving up chase does not snap back to room spawn.
function scr_enemy_grounded_patrol_reanchor_here() {
    var half = 140;
    if (variable_instance_exists(id, "gnd_patrol_half_width")) half = gnd_patrol_half_width;
    half = max(32, half);
    gnd_patrol_x1 = x - half;
    gnd_patrol_x2 = x + half;
}

/// @function scr_enemy_grounded_step
function scr_enemy_grounded_step() {
    if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0) hit_blink_timer--;
    if (gnd_state != GND_STATE_DEAD) {
        scr_enemy_grounded_physics_gravity_vertical();
    }
    switch (gnd_state) {
        case GND_STATE_PATROL: scr_enemy_grounded_state_patrol(); break;
        case GND_STATE_CHASE: scr_enemy_grounded_state_chase(); break;
        case GND_STATE_ATTACK: scr_enemy_grounded_state_attack(); break;
        case GND_STATE_DAMAGED: scr_enemy_grounded_state_damaged(); break;
        case GND_STATE_DEAD: scr_enemy_grounded_state_dead(); break;
        default: gnd_state = GND_STATE_PATROL; break;
    }
}

/// @function scr_enemy_grounded_state_patrol
function scr_enemy_grounded_state_patrol() {
    if (scr_enemy_grounded_can_see_player()) {
        gnd_state = GND_STATE_CHASE;
        return;
    }
    var _dir = scr_enemy_grounded_facing_sign();
    if (!scr_enemy_grounded_floor_or_ledge_ahead(_dir) || scr_enemy_grounded_wall_blocking_h(_dir)) {
        _dir = -_dir;
        gnd_facing = _dir;
    }
    scr_enemy_grounded_apply_hmove(_dir * move_speed);
    if (variable_instance_exists(id, "gnd_patrol_x1") && variable_instance_exists(id, "gnd_patrol_x2")) {
        var mn = min(gnd_patrol_x1, gnd_patrol_x2);
        var mx = max(gnd_patrol_x1, gnd_patrol_x2);
        if (x <= mn) { x = mn; gnd_facing = 1; }
        else if (x >= mx) { x = mx; gnd_facing = -1; }
    }
}

/// @function scr_enemy_grounded_melee_vertical_overlap_px
function scr_enemy_grounded_melee_vertical_overlap_px() {
    if (!instance_exists(obj_player)) return -99999;
    return min(bbox_bottom, obj_player.bbox_bottom) - max(bbox_top, obj_player.bbox_top);
}

/// @function scr_enemy_grounded_melee_horizontal_gap_px
/// @returns Pixels between closest vertical sides; 0 when overlapping on X.
function scr_enemy_grounded_melee_horizontal_gap_px() {
    if (!instance_exists(obj_player)) return 99999;
    if (bbox_right < obj_player.bbox_left) return obj_player.bbox_left - bbox_right;
    if (obj_player.bbox_right < bbox_left) return bbox_left - obj_player.bbox_right;
    return 0;
}

/// @function scr_enemy_grounded_melee_in_attack_range
/// @description Uses bbox edges + vertical overlap (not origin distance_to_object).
function scr_enemy_grounded_melee_in_attack_range() {
    if (!instance_exists(obj_player)) return false;
    var v_min = variable_instance_exists(id, "gnd_attack_vertical_overlap_min") ? gnd_attack_vertical_overlap_min : 10;
    if (scr_enemy_grounded_melee_vertical_overlap_px() < v_min) return false;
    return scr_enemy_grounded_melee_horizontal_gap_px() <= attack_range;
}

/// @function scr_enemy_grounded_state_chase
function scr_enemy_grounded_state_chase() {
    if (!instance_exists(obj_player)) {
        scr_enemy_grounded_patrol_reanchor_here();
        gnd_state = GND_STATE_PATROL;
        return;
    }
    if (!scr_enemy_grounded_can_see_player()) {
        scr_enemy_grounded_patrol_reanchor_here();
        gnd_state = GND_STATE_PATROL;
        return;
    }
    if (scr_enemy_grounded_melee_in_attack_range()) {
        gnd_state = GND_STATE_ATTACK;
        gnd_attack_timer = variable_instance_exists(id, "gnd_attack_duration") ? gnd_attack_duration : 28;
        gnd_attack_timer = max(4, gnd_attack_timer);
        return;
    }
    var _dir = sign(obj_player.x - x);
    if (_dir == 0) _dir = scr_enemy_grounded_facing_sign();
    // Never flip away from the player on a ledge — that walks into the wall behind you and freezes (hsp 0).
    if (!scr_enemy_grounded_floor_or_ledge_ahead(_dir)) _dir = 0;
    if (scr_enemy_grounded_wall_blocking_h(_dir)) _dir = 0;
    if (_dir != 0) {
        image_xscale = abs(image_xscale) * _dir;
        gnd_facing = _dir;
    } else if (instance_exists(obj_player)) {
        var _face = sign(obj_player.x - x);
        if (_face != 0) {
            image_xscale = abs(image_xscale) * _face;
            gnd_facing = _face;
        }
    }
    scr_enemy_grounded_apply_hmove(_dir * move_speed * 1.12);
}

/// @function scr_enemy_grounded_state_attack
function scr_enemy_grounded_state_attack() {
    if (instance_exists(obj_player)) {
        var _fd = sign(obj_player.x - x);
        if (_fd != 0) {
            image_xscale = abs(image_xscale) * _fd;
            gnd_facing = _fd;
        }
    }
    var _dur = variable_instance_exists(id, "gnd_attack_duration") ? gnd_attack_duration : 28;
    var _lunge = variable_instance_exists(id, "gnd_attack_lunge") ? gnd_attack_lunge : 0;
    var _lf = variable_instance_exists(id, "gnd_attack_lunge_frames") ? gnd_attack_lunge_frames : 8;
    _lf = min(_lf, _dur);
    if (_lunge != 0 && gnd_attack_timer > _dur - _lf) {
        scr_enemy_grounded_apply_hmove(sign(image_xscale) * _lunge);
    }
    gnd_attack_timer--;
    if (gnd_attack_timer <= 0) {
        if (scr_enemy_grounded_can_see_player()) {
            gnd_state = GND_STATE_CHASE;
        } else {
            scr_enemy_grounded_patrol_reanchor_here();
            gnd_state = GND_STATE_PATROL;
        }
    }
}

/// @function scr_enemy_grounded_state_damaged
function scr_enemy_grounded_state_damaged() {
    scr_enemy_grounded_apply_hmove(gnd_knock_h);
    gnd_knock_h = lerp(gnd_knock_h, 0, 0.22);
    gnd_hurt_stun_timer--;
    if (gnd_hurt_stun_timer <= 0) {
        if (scr_enemy_grounded_can_see_player()) {
            gnd_state = GND_STATE_CHASE;
        } else {
            scr_enemy_grounded_patrol_reanchor_here();
            gnd_state = GND_STATE_PATROL;
        }
    }
}

/// @function scr_enemy_grounded_state_dead
function scr_enemy_grounded_state_dead() {
    hspeed = 0;
    vspeed = 0;
    var _c = merge_color(c_white, c_ltgray, 0.25);
    repeat (18) {
        effect_create_below(ef_spark, x + random_range(-14, 14), y + random_range(-18, 8), irandom(2), _c);
    }
    effect_create_above(ef_explosion, x, y - 8, 2, merge_color(c_white, c_yellow, 0.35));
    instance_destroy();
}

/// @function scr_enemy_grounded_apply_damage
function scr_enemy_grounded_apply_damage(_amount, _attacker_x) {
    if (gnd_state == GND_STATE_DEAD) return;
    gnd_hp -= _amount;
    if (gnd_hp <= 0) {
        gnd_state = GND_STATE_DEAD;
        return;
    }
    gnd_state = GND_STATE_DAMAGED;
    gnd_hurt_stun_timer = variable_instance_exists(id, "gnd_hurt_stun_frames") ? gnd_hurt_stun_frames : 22;
    var _k = variable_instance_exists(id, "gnd_hurt_knockback_h") ? gnd_hurt_knockback_h : 4.5;
    var _dir = sign(x - _attacker_x);
    if (_dir == 0) _dir = -scr_enemy_grounded_facing_sign();
    gnd_knock_h = _dir * _k;
}

/// @function scr_player_grounded_damaged_hmove
function scr_player_grounded_damaged_hmove(_hurt_active) {
    if (!_hurt_active) return;
    if (variable_instance_exists(id, "hsp")) {
        hsp = lerp(hsp, 0, 0.2);
    } else if (variable_instance_exists(id, "hspeed")) {
        hspeed = lerp(hspeed, 0, 0.2);
    }
}
