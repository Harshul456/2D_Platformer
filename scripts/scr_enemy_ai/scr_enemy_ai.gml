/// @function scr_enemy_ai
/// @description Hierarchical threat FSM: Melee band (half-widths + chase_stop_extra) + LoS + DCD==0
///             → THREAT_REACTION → optional THREAT_NEUTRAL (20%) → weighted branch (25/45/30 + velocity scaling).
function scr_enemy_ai() {
    // --- Attack FSM: 0 = telegraph (still, red, no damage), 1 = dash, 2 = recovery
    if (state == STATE_ATTACK) {
        image_yscale = base_yscale;
        if (attack_phase == 0) {
            hsp = 0;
            scr_enemy_attack_windup_visuals();
            attack_phase_timer--;
            if (attack_phase_timer <= 0) {
                attack_phase = 1;
                attack_phase_timer = enemy_attack_dash_frames;
                attack_hit_dealt = false;
            }
        } else if (attack_phase == 1) {
            dash_sweep_prev_x = x;
            image_blend = c_white;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;
            if (instance_exists(obj_player)) {
                var _dd = sign(obj_player.x - x);
                if (_dd == 0) _dd = sign(image_xscale) != 0 ? sign(image_xscale) : 1;
                hsp = _dd * enemy_attack_dash_hsp;
                var _lx = (_dd > 0) ? bbox_right + 1 : bbox_left - 1;
                var _fy = bbox_bottom;
                var _ok = scr_enemy_forward_ledge_ok_horiz(_dd);
                if (!_ok) hsp = 0;
                if (_dd != 0) image_xscale = base_xscale * _dd;
            } else {
                hsp = 0;
            }
            attack_phase_timer--;
            if (attack_phase_timer <= 0) {
                attack_phase = 2;
                attack_phase_timer = enemy_attack_recovery_frames;
            }
        } else {
            hsp = 0;
            image_blend = c_white;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;
            attack_phase_timer--;
            if (attack_phase_timer <= 0) {
                if (instance_exists(obj_player)) {
                    var _dt = point_distance(x, y, obj_player.x, obj_player.y);
                    state = scr_enemy_resolve_chase_or_patrol_wide();
                } else {
                    state = STATE_IDLE;
                }
                attack_cooldown = attack_cooldown_max_frames;
                attack_phase = 0;
                attack_hit_dealt = false;
                was_in_attack_threat_zone = false;
                scr_enemy_start_decision_cooldown();
            }
        }
        return;
    }

    if (!instance_exists(obj_player)) {
        hsp = 0;
        return;
    }

    var _dist_x = abs(obj_player.x - x);
    var _dist_total = point_distance(x, y, obj_player.x, obj_player.y);
    var _dir = sign(obj_player.x - x);

    switch (state) {
        case STATE_IDLE:
            hsp = 0;
            image_yscale = base_yscale;
            image_blend = c_white;
            if (scr_enemy_can_chase_player()) {
                state = STATE_CHASE;
                chase_path_blocked_timer = 0;
            } else {
                scr_enemy_patrol_reanchor_here();
                state = STATE_PATROL;
            }
            break;

        case STATE_PATROL: {
            image_yscale = base_yscale;
            image_blend = c_white;
            if (scr_enemy_can_chase_player()) {
                state = STATE_CHASE;
                chase_path_blocked_timer = 0;
                hsp = 0;
                image_blend = c_white;
                break;
            }
            if (patrol_pause_timer > 0) {
                patrol_pause_timer--;
                hsp = 0;
                break;
            }
            var _margin = 24;
            var _lbound = max(_margin, spawn_x - patrol_range_px);
            var _rbound = min(room_width - _margin, spawn_x + patrol_range_px);
            if (_lbound >= _rbound - 8) {
                spawn_x = clamp(x, _margin, room_width - _margin);
                _lbound = max(_margin, spawn_x - 48);
                _rbound = min(room_width - _margin, spawn_x + 48);
            }
            var _plead = (patrol_dir > 0) ? bbox_right + 1 : bbox_left - 1;
            var _pfeet = bbox_bottom;
            var _pg = check_tile_collision(_plead, _pfeet + 1) || check_tile_collision(_plead, _pfeet + 4);
            if (_pg && scr_enemy_forward_ledge_ok_horiz(patrol_dir)) {
                hsp = patrol_dir * patrol_speed;
            } else {
                hsp = 0;
                patrol_dir = -patrol_dir;
                patrol_pause_timer = irandom_range(patrol_edge_pause_min, patrol_edge_pause_max);
            }
            if (patrol_dir != 0) image_xscale = base_xscale * patrol_dir;
            if (x <= _lbound + 2) {
                patrol_dir = 1;
                x = max(x, _lbound);
                patrol_pause_timer = irandom_range(patrol_edge_pause_min, patrol_edge_pause_max);
                hsp = 0;
            } else if (x >= _rbound - 2) {
                patrol_dir = -1;
                x = min(x, _rbound);
                patrol_pause_timer = irandom_range(patrol_edge_pause_min, patrol_edge_pause_max);
                hsp = 0;
            }
        } break;
        case STATE_THREAT_REACTION: {
            hsp = 0;
            image_blend = enemy_threat_zone_blend;
            image_yscale = base_yscale;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            var _rehw = (bbox_right - bbox_left) * 0.5;
            var _rphw = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            var _rstop = (_rehw + _rphw) + chase_stop_extra;
            var _r_pin = (attack_cooldown <= 0 && _dist_x <= _rstop && scr_enemy_los_to_player()
                && scr_enemy_horiz_channel_clear_feet());

            if (_dir != 0) image_xscale = base_xscale * _dir;

            if (!_r_pin) {
                state = scr_enemy_resolve_chase_or_patrol_wide();
                was_in_attack_threat_zone = false;
                threat_neutral_is_exhaustion = false;
                break;
            }

            threat_reaction_timer--;
            if (threat_reaction_timer > 0) break;

            if (threat_commit_count >= enemy_threat_commit_exhaust_at) {
                state = STATE_THREAT_NEUTRAL;
                threat_neutral_timer = irandom_range(enemy_exhaustion_neutral_min, enemy_exhaustion_neutral_max);
                threat_neutral_is_exhaustion = true;
            } else if (random(1) < enemy_threat_neutral_chance) {
                state = STATE_THREAT_NEUTRAL;
                threat_neutral_timer = irandom_range(enemy_threat_neutral_min, enemy_threat_neutral_max);
                threat_neutral_is_exhaustion = false;
            } else {
                scr_enemy_roll_threat_branch();
                threat_commit_count++;
            }
        } break;

        case STATE_THREAT_NEUTRAL: {
            hsp = 0;
            image_blend = enemy_threat_zone_blend;
            image_yscale = base_yscale;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            var _nehw = (bbox_right - bbox_left) * 0.5;
            var _nphw = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            var _nstop = (_nehw + _nphw) + chase_stop_extra;
            var _n_pin = (attack_cooldown <= 0 && _dist_x <= _nstop && scr_enemy_los_to_player()
                && scr_enemy_horiz_channel_clear_feet());

            if (_dir != 0) image_xscale = base_xscale * _dir;

            if (!_n_pin) {
                state = scr_enemy_resolve_chase_or_patrol_wide();
                was_in_attack_threat_zone = false;
                threat_neutral_is_exhaustion = false;
                break;
            }

            threat_neutral_timer--;
            if (threat_neutral_timer > 0) break;

            if (threat_neutral_is_exhaustion) {
                scr_enemy_roll_threat_branch();
                threat_commit_count = 0;
                threat_neutral_is_exhaustion = false;
            } else {
                scr_enemy_roll_threat_branch();
                threat_commit_count++;
            }
        } break;

        case STATE_PATIENT_WAIT: {
            hsp = 0;
            image_blend = make_color_rgb(255, 210, 72);
            image_yscale = base_yscale * 0.92;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            var _pehw = (bbox_right - bbox_left) * 0.5;
            var _pphw = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            var _pstop = (_pehw + _pphw) + chase_stop_extra;
            var _pin_threat = (attack_cooldown <= 0 && _dist_x <= _pstop && scr_enemy_los_to_player()
                && scr_enemy_horiz_channel_clear_feet());

            if (_dir != 0) image_xscale = base_xscale * _dir;

            if (!_pin_threat) {
                state = scr_enemy_resolve_chase_or_patrol_wide();
                was_in_attack_threat_zone = false;
                image_yscale = base_yscale;
                image_blend = c_white;
                break;
            }

            patient_wait_timer--;
            if (patient_wait_timer <= 0) {
                state = STATE_ATTACK;
                attack_phase = 0;
                attack_phase_timer = enemy_attack_windup_frames;
                attack_hit_dealt = false;
                image_yscale = base_yscale;
                scr_enemy_attack_windup_visuals();
            }
        } break;

        case STATE_DEFENSIVE_RETREAT: {
            image_blend = enemy_threat_retreat_blend;
            image_yscale = base_yscale;
            var _away = -_dir;
            if (_away == 0) _away = -sign(image_xscale);
            if (_away == 0) _away = -1;

            var _lead_xr = (_away > 0) ? bbox_right + 1 : bbox_left - 1;
            var _feet_yr = bbox_bottom;
            var _ground_r = check_tile_collision(_lead_xr, _feet_yr + 1) || check_tile_collision(_lead_xr, _feet_yr + 4);
            if (_ground_r && scr_enemy_forward_ledge_ok_horiz(_away)) {
                hsp = _away * enemy_defensive_retreat_hsp;
            } else {
                hsp = 0;
            }
            if (_away != 0) image_xscale = base_xscale * _away;

            retreat_intended_hsp = hsp;

            retreat_timer--;
            if (retreat_timer <= 0) {
                state = scr_enemy_resolve_chase_or_patrol_wide();
                attack_cooldown = max(attack_cooldown, enemy_defensive_post_cooldown);
                hsp = 0;
                image_blend = c_white;
                was_in_attack_threat_zone = false;
                retreat_wall_stall = 0;
                retreat_intended_hsp = 0;
                scr_enemy_start_decision_cooldown();
            }
        } break;

        case STATE_CHASE: {
            image_yscale = base_yscale;
            var _enemy_half_w  = (bbox_right - bbox_left) * 0.5;
            var _player_half_w = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            var _stop_distance = (_enemy_half_w + _player_half_w) + chase_stop_extra;

            if (_dist_x > _stop_distance) {
                var _lead_x = (_dir > 0) ? bbox_right + 1 : bbox_left - 1;
                var _feet_y = bbox_bottom;
                var _ground_ahead = check_tile_collision(_lead_x, _feet_y + 1) ||
                                   check_tile_collision(_lead_x, _feet_y + 4);
                if (_ground_ahead) {
                    hsp = _dir * moveSpeed;
                } else {
                    hsp = 0;
                }
            } else {
                hsp = 0;
            }

            if (decision_cooldown_timer > 0) hsp *= enemy_decision_cooldown_move_scale;

            if (_dir != 0) image_xscale = base_xscale * _dir;

            var _path_ok = scr_enemy_horiz_channel_clear_feet();
            var _los_ok = scr_enemy_los_to_player();
            // Count separation even in standoff: want_close was false so we never gave up hugging a wall.
            var _near_encounter = (_dist_total < chaseRange * 1.2);
            if (_near_encounter && (!_los_ok || !_path_ok)) {
                chase_path_blocked_timer++;
                if (chase_path_blocked_timer >= enemy_chase_path_blocked_frames) {
                    scr_enemy_patrol_reanchor_here();
                    state = STATE_PATROL;
                    chase_path_blocked_timer = 0;
                    hsp = 0;
                    patrol_pause_timer = irandom_range(8, 28);
                    was_in_attack_threat_zone = false;
                    image_blend = c_white;
                    break;
                }
            } else if (!_near_encounter || (_los_ok && _path_ok)) {
                chase_path_blocked_timer = max(0, chase_path_blocked_timer - 2);
            }

            var _melee_band = _stop_distance;
            var _in_threat = (attack_cooldown <= 0 && decision_cooldown_timer <= 0 && _dist_x <= _melee_band
                && scr_enemy_los_to_player() && scr_enemy_horiz_channel_clear_feet());
            var _entered_threat = _in_threat && !was_in_attack_threat_zone;

            if (_entered_threat) {
                was_in_attack_threat_zone = true;
                chase_path_blocked_timer = 0;
                state = STATE_THREAT_REACTION;
                threat_reaction_timer = irandom_range(enemy_threat_reaction_min, enemy_threat_reaction_max);
                break;
            }

            if (!_in_threat) was_in_attack_threat_zone = false;

            if (_dist_total > chaseRange * 1.2) {
                scr_enemy_patrol_reanchor_here();
                state = STATE_PATROL;
                hsp = 0;
                was_in_attack_threat_zone = false;
                patrol_pause_timer = irandom_range(6, 22);
            }

            var _zone_geom = (attack_cooldown <= 0 && decision_cooldown_timer <= 0 && _dist_x <= _melee_band
                && scr_enemy_los_to_player() && scr_enemy_horiz_channel_clear_feet());
            image_blend = _zone_geom ? enemy_threat_zone_blend : c_white;
        } break;

        case STATE_AGGRESSIVE: {
            image_yscale = base_yscale;
            var _enemy_half_w2  = (bbox_right - bbox_left) * 0.5;
            var _player_half_w2 = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            var _stop_distance2 = (_enemy_half_w2 + _player_half_w2) + chase_stop_extra;

            if (_dist_x > _stop_distance2) {
                var _lead_x2 = (_dir > 0) ? bbox_right + 1 : bbox_left - 1;
                var _feet_y2 = bbox_bottom;
                var _ground_ahead2 = check_tile_collision(_lead_x2, _feet_y2 + 1) ||
                                    check_tile_collision(_lead_x2, _feet_y2 + 4);
                if (_ground_ahead2) {
                    hsp = _dir * moveSpeed;
                } else {
                    hsp = 0;
                }
            } else {
                hsp = 0;
            }

            if (decision_cooldown_timer > 0) hsp *= enemy_decision_cooldown_move_scale;

            if (_dir != 0) image_xscale = base_xscale * _dir;

            var _path_ok2 = scr_enemy_horiz_channel_clear_feet();
            var _los_ok2 = scr_enemy_los_to_player();
            var _near_encounter2 = (_dist_total < chaseRange * 1.2);
            if (_near_encounter2 && (!_los_ok2 || !_path_ok2)) {
                chase_path_blocked_timer++;
                if (chase_path_blocked_timer >= enemy_chase_path_blocked_frames) {
                    scr_enemy_patrol_reanchor_here();
                    state = STATE_PATROL;
                    chase_path_blocked_timer = 0;
                    hsp = 0;
                    patrol_pause_timer = irandom_range(8, 28);
                    was_in_attack_threat_zone = false;
                    image_blend = c_white;
                    break;
                }
            } else if (!_near_encounter2 || (_los_ok2 && _path_ok2)) {
                chase_path_blocked_timer = max(0, chase_path_blocked_timer - 2);
            }

            var _melee_band2 = _stop_distance2;
            var _in_threat2 = (attack_cooldown <= 0 && decision_cooldown_timer <= 0 && _dist_x <= _melee_band2
                && scr_enemy_los_to_player() && scr_enemy_horiz_channel_clear_feet());
            var _entered_threat2 = _in_threat2 && !was_in_attack_threat_zone;

            if (_entered_threat2) {
                was_in_attack_threat_zone = true;
                chase_path_blocked_timer = 0;
                state = STATE_THREAT_REACTION;
                threat_reaction_timer = irandom_range(enemy_threat_reaction_min, enemy_threat_reaction_max);
                break;
            }

            if (!_in_threat2) was_in_attack_threat_zone = false;

            if (aggressive_timer > 0) aggressive_timer--;
            if (aggressive_timer <= 0) {
                if (scr_enemy_can_chase_player()) {
                    state = STATE_CHASE;
                } else {
                    scr_enemy_patrol_reanchor_here();
                    state = STATE_PATROL;
                }
            }

            if (_dist_total > chaseRange * 1.2) {
                scr_enemy_patrol_reanchor_here();
                state = STATE_PATROL;
                hsp = 0;
                was_in_attack_threat_zone = false;
                patrol_pause_timer = irandom_range(6, 22);
            }

            var _zone_geom2 = (attack_cooldown <= 0 && decision_cooldown_timer <= 0 && _dist_x <= _melee_band2
                && scr_enemy_los_to_player() && scr_enemy_horiz_channel_clear_feet());
            image_blend = _zone_geom2 ? enemy_threat_zone_blend : c_white;
        } break;
    }

    if (global.show_debug && (state == STATE_CHASE || state == STATE_PATROL || state == STATE_THREAT_REACTION || state == STATE_THREAT_NEUTRAL
            || state == STATE_PATIENT_WAIT || state == STATE_DEFENSIVE_RETREAT)) {
        show_debug_message("Enemy state: " + string(state) + " | Dist_X: " + string(_dist_x) + " | dcd: " + string(decision_cooldown_timer));
    }
}

/// @function scr_enemy_start_decision_cooldown
/// @description After attack recovery or retreat: block new threat pipeline + allow fresh edge trigger.
function scr_enemy_start_decision_cooldown() {
    decision_cooldown_timer = irandom_range(enemy_decision_cooldown_min, enemy_decision_cooldown_max);
    was_in_attack_threat_zone = false;
}

/// @function scr_enemy_roll_threat_branch
/// @description Stage 3: single random(1) vs [Aggressive | Patient | Retreat] with velocity/proximity scaling.
function scr_enemy_roll_threat_branch() {
    var A = enemy_branch_aggressive;
    var P = enemy_branch_patient_prob;
    var R = enemy_branch_retreat_prob;
    
    if (threat_next_roll_retreat_bias) {
        A = enemy_bias_scared_aggressive;
        P = max(0.05, enemy_bias_scared_patient_cumulative - A);
        R = max(0.05, 1 - enemy_bias_scared_patient_cumulative);
        threat_next_roll_retreat_bias = false;
    } else {
        if (last_branch_was_retreat) {
            P = min(0.72, P + enemy_retreat_repeat_patient_shift);
            R = max(0.04, R - enemy_retreat_repeat_patient_shift * 0.65);
        }
        if (pressure_hit_count > enemy_pressure_hits_threshold) {
            P -= enemy_pressure_retreat_patient_pull;
            R += enemy_pressure_retreat_patient_pull;
        }
    }
    
    var _s0 = A + P + R;
    if (_s0 > 0) {
        A /= _s0;
        P /= _s0;
        R /= _s0;
    }
    
    if (instance_exists(obj_player)) {
        var _dxs = abs(obj_player.x - x);
        var _sep = sign(obj_player.x - x);
        var _toward_enemy = (_dxs >= 1) && (sign(obj_player.hsp) == -_sep);
        var _rush = (abs(obj_player.hsp) >= enemy_branch_rush_hsp_threshold) && _toward_enemy;
        if (_dxs < enemy_branch_proximity_px || _rush) {
            A *= enemy_branch_pressure_weight_mult;
            R *= enemy_branch_pressure_weight_mult;
            var _s1 = A + P + R;
            if (_s1 > 0) {
                A /= _s1;
                P /= _s1;
                R /= _s1;
            }
        }
        var _moving_away = false;
        if (_dxs >= 1) {
            _moving_away = (abs(obj_player.hsp) >= enemy_branch_away_hsp_threshold)
                && (sign(obj_player.hsp) == _sep);
        }
        if (_moving_away) {
            R = 0;
            var _s2 = A + P;
            if (_s2 > 0) {
                A /= _s2;
                P /= _s2;
            }
        }
    }
    
    A = max(0.02, A);
    P = max(0.02, P);
    R = max(0, R);
    var _sn = A + P + R;
    if (_sn > 0) {
        A /= _sn;
        P /= _sn;
        R /= _sn;
    }
    
    var _rng = random(1);
    if (_rng < A) {
        last_branch_was_retreat = false;
        state = STATE_ATTACK;
        attack_phase = 0;
        attack_phase_timer = enemy_attack_windup_frames;
        attack_hit_dealt = false;
        scr_enemy_attack_windup_visuals();
    } else if (_rng < A + P) {
        last_branch_was_retreat = false;
        state = STATE_PATIENT_WAIT;
        patient_wait_timer = irandom_range(enemy_patient_wait_min, enemy_patient_wait_max);
    } else {
        last_branch_was_retreat = true;
        state = STATE_DEFENSIVE_RETREAT;
        retreat_wall_stall = 0;
        retreat_intended_hsp = 0;
        var _fmin = ceil(enemy_retreat_min_px / max(0.25, abs(enemy_defensive_retreat_hsp)));
        retreat_timer = max(enemy_defensive_retreat_frames, _fmin);
    }
}

/// @function scr_enemy_attack_windup_visuals
/// @description Red telegraph + shake; call the same frame you enter STATE_ATTACK phase 0 (attack block runs next Step).
function scr_enemy_attack_windup_visuals() {
    image_blend = make_color_rgb(255, 72, 88);
    telegraph_shake_x = random_range(-2.5, 2.5);
    telegraph_shake_y = random_range(-1.5, 1.5);
}

/// @function scr_enemy_horiz_channel_clear_feet
/// @description Samples tiles along X toward the player at feet/chest height — false if a wall blocks pursuit.
function scr_enemy_horiz_channel_clear_feet() {
    if (!instance_exists(obj_player)) return false;
    if (global.tilemap_collision_id == noone) return true;
    var _sep = sign(obj_player.x - x);
    if (_sep == 0) return true;
    var _my = (bbox_top + bbox_bottom) * 0.5;
    var _cx = (bbox_left + bbox_right) * 0.5;
    var _tx = (obj_player.bbox_left + obj_player.bbox_right) * 0.5;
    var _dist = abs(_tx - _cx);
    var _step = 10;
    var _steps = max(1, ceil(_dist / _step));
    for (var _hi = 1; _hi <= _steps; _hi++) {
        var _sx = _cx + _sep * min(_dist, _hi * _step);
        if (check_tile_collision(_sx, _my) || check_tile_collision(_sx, _my - 16)) return false;
    }
    return true;
}

/// @function scr_enemy_can_chase_player
/// @description True when player is in chase range with clear LoS and walkable channel (no wall between).
function scr_enemy_can_chase_player() {
    if (!instance_exists(obj_player)) return false;
    if (point_distance(x, y, obj_player.x, obj_player.y) >= chaseRange) return false;
    if (!scr_enemy_los_to_player()) return false;
    if (!scr_enemy_horiz_channel_clear_feet()) return false;
    return true;
}

/// @function scr_enemy_patrol_reanchor_here
/// @description Patrol leash follows where we gave up chase / lost LoS — not the room spawn.
function scr_enemy_patrol_reanchor_here() {
    var _m = 48;
    spawn_x = clamp(x, _m, room_width - _m);
}

/// @function scr_enemy_resolve_chase_or_patrol_wide
/// @description After combat / threat dropout: CHASE if reachable in extended radius, else PATROL.
function scr_enemy_resolve_chase_or_patrol_wide() {
    if (!instance_exists(obj_player)) return STATE_IDLE;
    var _dt = point_distance(x, y, obj_player.x, obj_player.y);
    if (_dt < chaseRange * 1.2 && scr_enemy_los_to_player() && scr_enemy_horiz_channel_clear_feet())
        return STATE_CHASE;
    scr_enemy_patrol_reanchor_here();
    return STATE_PATROL;
}

/// @function scr_enemy_tile_line_blocked
/// @description True if any solid tile lies along the segment (exclusive-ish sampling for LoS).
function scr_enemy_tile_line_blocked(_x1, _y1, _x2, _y2) {
    if (global.tilemap_collision_id == noone) return false;
    var _steps = max(2, ceil(point_distance(_x1, _y1, _x2, _y2) / 8));
    for (var _i = 1; _i < _steps; _i++) {
        var _t = _i / _steps;
        var _sx = lerp(_x1, _x2, _t);
        var _sy = lerp(_y1, _y2, _t);
        if (check_tile_collision(_sx, _sy)) return true;
    }
    return false;
}

/// @function scr_enemy_los_to_player
/// @description Line-of-sight: center + feet-level tile rays (short walls) + obj_solid lines.
function scr_enemy_los_to_player() {
    if (!instance_exists(obj_player)) return false;
    var _x1 = (bbox_left + bbox_right) * 0.5;
    var _y1 = (bbox_top + bbox_bottom) * 0.5;
    var _x2 = (obj_player.bbox_left + obj_player.bbox_right) * 0.5;
    var _y2 = (obj_player.bbox_top + obj_player.bbox_bottom) * 0.5;
    if (scr_enemy_tile_line_blocked(_x1, _y1, _x2, _y2)) return false;
    var _yf1 = bbox_bottom - 6;
    var _yf2 = obj_player.bbox_bottom - 6;
    if (scr_enemy_tile_line_blocked(_x1, _yf1, _x2, _yf2)) return false;
    if (collision_line(_x1, _y1, _x2, _y2, obj_solid, true, true) != noone) return false;
    if (collision_line(_x1, _yf1, _x2, _yf2, obj_solid, true, true) != noone) return false;
    return true;
}

/// @function scr_enemy_forward_ledge_ok_horiz
/// @description Down-angled forward probe so dash/retreat does not walk off ledges (_dir_sign: -1 or +1).
function scr_enemy_forward_ledge_ok_horiz(_dir_sign) {
    if (_dir_sign == 0) return false;
    var _feet = bbox_bottom;
    var _lead = (_dir_sign > 0) ? bbox_right + 1 : bbox_left - 1;
    var _near = check_tile_collision(_lead, _feet + 1) || check_tile_collision(_lead, _feet + 4);
    var _dx = _dir_sign * 14;
    var _diag_ok = check_tile_collision(_lead + _dx, _feet + 10) || check_tile_collision(_lead + _dx * 0.5, _feet + 6);
    return _near || _diag_ok;
}
