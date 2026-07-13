/// Lean Hollow Knight-style enemy FSM (replaces legacy threat pipeline / branch rolls).

enum ENEMY_STATE {
    PATROL,
    NOTICE,
    CHASE,
    TELEGRAPH,
    ATTACK,
    RECOIL,
    STUNNED
}

/// @function scr_enemy_facing_sign
/// @returns {Real} Logical facing (-1 left, 1 right).
function scr_enemy_facing_sign() {
    if (variable_instance_exists(id, "enemy_face_dir") && enemy_face_dir != 0) return enemy_face_dir;
    return 1;
}

/// @function scr_enemy_draw_xscale
/// @description Draw-only flip — image_xscale stays positive so collision/movement stay symmetric.
function scr_enemy_draw_xscale() {
    var _base = variable_instance_exists(id, "base_xscale") ? abs(base_xscale) : abs(image_xscale);
    if (_base == 0) _base = 1;
    return _base * scr_enemy_facing_sign();
}

/// @function scr_enemy_set_facing
/// @description Updates logical facing only. Never negative image_xscale (flipped bbox blocked left movement).
function scr_enemy_set_facing(_move_dir) {
    if (_move_dir == 0) return;
    enemy_face_dir = sign(_move_dir);
    image_xscale = abs(base_xscale);
}

/// @function scr_enemy_dir_toward_x
/// @param {Real} _tx Target x.
/// @returns {Real} -1, 0, or 1.
function scr_enemy_dir_toward_x(_tx) {
    if (_tx > x) return 1;
    if (_tx < x) return -1;
    return 0;
}

/// @function scr_enemy_dir_toward_player
/// @description Bbox-centre facing — instance x origins can lie when sprites are asymmetric.
function scr_enemy_dir_toward_player() {
    if (!instance_exists(obj_player)) return 0;
    var _pcx = (obj_player.bbox_left + obj_player.bbox_right) * 0.5;
    var _ecx = (bbox_left + bbox_right) * 0.5;
    if (_pcx > _ecx) return 1;
    if (_pcx < _ecx) return -1;
    return 0;
}

/// @function scr_enemy_hgap_to_player
/// @description Horizontal gap between closest bbox edges (0 when overlapping on X).
function scr_enemy_hgap_to_player() {
    if (!instance_exists(obj_player)) return 9999;
    if (obj_player.bbox_right < bbox_left) return bbox_left - obj_player.bbox_right;
    if (bbox_right < obj_player.bbox_left) return obj_player.bbox_left - bbox_right;
    return 0;
}

/// @function scr_enemy_attack_dash_reach_px
/// @returns {Real} Horizontal travel during the ATTACK dash (hsp * frames).
function scr_enemy_attack_dash_reach_px() {
    var _hsp = (variable_instance_exists(id, "enemy_attack_dash_hsp") ? enemy_attack_dash_hsp : 3.6);
    var _frames = (variable_instance_exists(id, "enemy_attack_dash_frames") ? enemy_attack_dash_frames : 14);
    return _hsp * _frames;
}

/// @function scr_enemy_melee_telegraph_hgap_max
/// @description Max bbox-edge gap to start telegraph — must be close enough for dash to connect.
/// @returns {Real}
function scr_enemy_melee_telegraph_hgap_max() {
    if (variable_instance_exists(id, "chase_telegraph_hgap_max")) {
        return chase_telegraph_hgap_max;
    }
    var _buf = (variable_instance_exists(id, "chase_telegraph_hgap_buffer") ? chase_telegraph_hgap_buffer : 12);
    return max(6, scr_enemy_attack_dash_reach_px() - _buf);
}

/// @function scr_enemy_melee_approach_slow_hgap
/// @description Wider edge-gap zone to creep slower while closing — not attack range.
function scr_enemy_melee_approach_slow_hgap() {
    return (variable_instance_exists(id, "chase_approach_slow_hgap") ? chase_approach_slow_hgap : 48);
}

/// @function scr_enemy_melee_band
/// @returns {Real} @deprecated Use scr_enemy_melee_telegraph_hgap_max — kept for callers.
function scr_enemy_melee_band() {
    return scr_enemy_melee_telegraph_hgap_max();
}

/// @function scr_enemy_player_in_melee_band
function scr_enemy_player_in_melee_band() {
    if (!instance_exists(obj_player)) return false;
    return scr_enemy_hgap_to_player() <= scr_enemy_melee_telegraph_hgap_max();
}

/// @function scr_enemy_touching_solid_wall
function scr_enemy_touching_solid_wall() {
    if (place_meeting(x, y, obj_solid)) return true;
    var _cy = (bbox_top + bbox_bottom) * 0.5;
    return check_tile_collision(bbox_left - 1, _cy) || check_tile_collision(bbox_right + 1, _cy);
}

/// @function scr_enemy_melee_vertical_overlap_px
/// @returns {Real} Vertical bbox overlap with player (negative when on different heights).
function scr_enemy_melee_vertical_overlap_px() {
    if (!instance_exists(obj_player)) return -99999;
    return min(bbox_bottom, obj_player.bbox_bottom) - max(bbox_top, obj_player.bbox_top);
}

/// @function scr_enemy_player_vertically_aligned_for_melee
/// @description True when player shares enough vertical band for a fair melee telegraph/dash.
function scr_enemy_player_vertically_aligned_for_melee() {
    var _min = (variable_instance_exists(id, "chase_melee_vertical_overlap_min")
        ? chase_melee_vertical_overlap_min : 10);
    return scr_enemy_melee_vertical_overlap_px() >= _min;
}

/// @function scr_enemy_player_above_unreachable
/// @description Player is on a higher ledge — horizontal chase cannot reach them for melee.
function scr_enemy_player_above_unreachable() {
    if (!instance_exists(obj_player)) return false;
    if (scr_enemy_player_vertically_aligned_for_melee()) return false;
    var _band = (variable_instance_exists(id, "chase_above_unreachable_px") ? chase_above_unreachable_px : 12);
    return obj_player.bbox_bottom < bbox_top + _band;
}

/// @function scr_enemy_begin_notice
/// @description HK threat reaction — freeze, face player, blue alert tint, then commit to chase.
function scr_enemy_begin_notice() {
    state = ENEMY_STATE.NOTICE;
    state_timer = (variable_instance_exists(id, "enemy_notice_frames") ? enemy_notice_frames : 30);
    hsp = 0;
    lost_los_timer = 0;
    chase_path_blocked_timer = 0;
    chase_wall_stuck_timer = 0;
    if (instance_exists(obj_player)) {
        scr_enemy_set_facing(scr_enemy_dir_toward_player());
    }
    scr_enemy_notice_visuals();
}

/// @function scr_enemy_notice_visuals
function scr_enemy_notice_visuals() {
    var _pulse = ((current_time div 90) mod 2 == 0);
    image_blend = _pulse ? make_color_rgb(72, 140, 255) : make_color_rgb(108, 168, 255);
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;
}

/// @function scr_enemy_hit_armor_policy
/// @description Active armor intercept rules for committed enemy phases.
/// @returns {Struct} { intercept, take_damage, take_stun, take_knockback, damage_mult }
function scr_enemy_hit_armor_policy() {
    switch (state) {
        case ENEMY_STATE.NOTICE:
            return { intercept: true, take_damage: false, take_stun: false, take_knockback: false, damage_mult: 0 };
        case ENEMY_STATE.ATTACK:
            // Super armor — active dash slices through nail hits.
            return { intercept: true, take_damage: false, take_stun: false, take_knockback: false, damage_mult: 0 };
        case ENEMY_STATE.RECOIL:
            if (variable_instance_exists(id, "attack_hit_dealt") && attack_hit_dealt) {
                return { intercept: true, take_damage: false, take_stun: false, take_knockback: false, damage_mult: 0 };
            }
            return { intercept: false, take_damage: true, take_stun: true, take_knockback: true, damage_mult: 1 };
        case ENEMY_STATE.TELEGRAPH:
            // Regular armor — chip damage during red tell; windup is not interruptible.
            return { intercept: false, take_damage: true, take_stun: false, take_knockback: false, damage_mult: 1 };
        default:
            return { intercept: false, take_damage: true, take_stun: true, take_knockback: true, damage_mult: 1 };
    }
}

/// @function scr_enemy_armor_deflect_feedback
/// @description Clang feedback when a swing is absorbed — no damage/stun.
function scr_enemy_armor_deflect_feedback() {
    if (!variable_instance_exists(id, "impact_spark_list")) impact_spark_list = [];
    repeat (3) {
        array_push(impact_spark_list, scr_crystal_spark_create(x, y - 8));
    }
}

/// @function scr_enemy_begin_telegraph
/// @description Contact braking → committed warning; dash direction locked at start (anti-bait).
function scr_enemy_begin_telegraph() {
    var _commit_dir = scr_enemy_facing_sign();
    if (instance_exists(obj_player)) {
        var _toward = scr_enemy_dir_toward_player();
        if (_toward != 0) _commit_dir = _toward;
    }

    telegraph_commit_dir = _commit_dir;
    state = ENEMY_STATE.TELEGRAPH;
    state_timer = enemy_telegraph_frames;
    hsp = 0;
    attack_hit_dealt = false;
    attack_frame = 0;
    dash_sweep_prev_x = x;
    scr_enemy_set_facing(_commit_dir);
    scr_enemy_attack_windup_visuals();
}

/// @function scr_enemy_begin_attack_dash
/// @description Locked launch after telegraph — uses committed direction, not live player bait.
function scr_enemy_begin_attack_dash() {
    var _dir = (variable_instance_exists(id, "telegraph_commit_dir") && telegraph_commit_dir != 0)
        ? telegraph_commit_dir : scr_enemy_facing_sign();
    if (_dir == 0) _dir = 1;
    state = ENEMY_STATE.ATTACK;
    attack_hit_dealt = false;
    attack_frame = 0; // sweep gated until Step increments (no TELEGRAPH/CHASE damage)
    dash_sweep_prev_x = x;
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;
    hsp = _dir * enemy_attack_dash_hsp;
    image_blend = c_white;
    scr_enemy_set_facing(_dir);
}

/// @function scr_enemy_attack_hitbox_active
/// @description Waist-height sweep line — ATTACK dash frames only (never CHASE / TELEGRAPH).
function scr_enemy_attack_hitbox_active() {
    return (state == ENEMY_STATE.ATTACK && attack_frame > 0);
}

/// @function scr_enemy_resolve_attack_player_contact
/// @description ATTACK-only sweep; body contact ends dash (no pass-through). No player attack i-frames.
/// @returns {Bool} True if player body was struck this step.
function scr_enemy_resolve_attack_player_contact() {
    if (!scr_enemy_attack_hitbox_active() || attack_hit_dealt || !instance_exists(obj_player)) return false;

    var _yc = (bbox_top + bbox_bottom) * 0.5;
    var _contact = place_meeting(x, y, obj_player)
        || (collision_line(dash_sweep_prev_x, _yc, x, _yc, obj_player, true, true) != noone);
    if (!_contact) return false;

    with (obj_player) {
        if (!invincible) {
            obj_player_health -= other.enemy_attack_damage;
            var _push_dir = sign(x - other.x);
            if (_push_dir == 0) _push_dir = -last_direction;
            knockBackX = _push_dir * other.enemy_attack_hsp_push;
            knockBackY = ENEMY_KNOCKBACK_Y;
            stunTimer = ENEMY_STUN_FRAMES;
            attacking = false;
            attack_lockout = 0;
            attack_commit_lock = 0;
            attack_recovery_lock = 0;
            attackCooldownTimer = 0;
            attack_buffer_timer = 0;
            attack_chain_buffer_timer = 0;
            attack_chain_latched = false;
            attack_shift_remaining = 0;
            combo_buffer = false;
            comboTimer = 0;
            comboCount = 0;
            debug_hitbox_active = false;
            is_sprinting = false;
            sprint_afterimage_tick = 0;
            sprint_jump_carry = false;
            sprint_air_trail = false;
            invincible = true;
            invincibleTimer = INVINCIBILITY_FRAMES;
            attack_priority_timer = 0;
        }
    }

    scr_camera_trigger_shake(6, 12);
    scr_hitstop_trigger(3);

    // Stop on body contact — never ghost through the player.
    hsp = 0;
    state = ENEMY_STATE.RECOIL;
    state_timer = enemy_recover_frames;
    image_blend = c_white;
    attack_hit_dealt = true;
    return true;
}

/// @function scr_enemy_post_stun_recovery
/// @description Recover from stun — poise window lets enemy close through light mash hits.
function scr_enemy_post_stun_recovery() {
    knockbackX = 0;
    hsp = 0;
    attack_hit_dealt = false;
    attack_frame = 0;
    image_blend = c_white;
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;
    lost_los_timer = 0;
    chase_path_blocked_timer = 0;
    state = ENEMY_STATE.CHASE;

    var _poise = (variable_instance_exists(id, "enemy_poise_frames") ? enemy_poise_frames : 48);
    enemy_poise_timer = _poise;
}

/// @function scr_enemy_chase_hsp_for_distance
/// @description Full speed until approach zone; creep when close; stop only at telegraph range.
function scr_enemy_chase_hsp_for_distance(_hgap, _dir) {
    if (_dir == 0) return 0;

    var _telegraph_hgap = scr_enemy_melee_telegraph_hgap_max();
    if (_hgap <= _telegraph_hgap) return 0;

    var _hsp = _dir * moveSpeed;
    var _approach_hgap = scr_enemy_melee_approach_slow_hgap();
    if (_hgap < _approach_hgap) {
        _hsp *= enemy_approach_slow_factor;
    }
    return _hsp;
}

/// @function scr_enemy_on_player_hit
/// @description Armor intercept + stun resolution when the player attack connects.
/// @param {Real} _combo_count Player combo step (1 or 2).
/// @returns {Struct} { landed, intercepted, armored_chip }
function scr_enemy_on_player_hit(_combo_count) {
    var _policy = scr_enemy_hit_armor_policy();
    var _was_telegraph = (state == ENEMY_STATE.TELEGRAPH);
    var _was_attack = (state == ENEMY_STATE.ATTACK);

    // Super armor — dash phase; no damage, full intercept.
    if (_policy.intercept) {
        var _cd = (variable_instance_exists(id, "armor_deflect_cooldown") ? armor_deflect_cooldown : 0);
        if (_cd <= 0) {
            var _cd_max = (variable_instance_exists(id, "armor_deflect_cooldown_frames")
                ? armor_deflect_cooldown_frames : 10);
            armor_deflect_cooldown = _cd_max;
            scr_enemy_armor_deflect_feedback();
        }
        return { landed: false, intercepted: true, armored_chip: false, super_armor: _was_attack };
    }

    hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
    obj_enemy_health -= other.ATTACK_DAMAGE_PER_HIT * _policy.damage_mult;

    // Regular armor — telegraph chips but cannot be interrupted or shoved.
    if (!_policy.take_stun && !_policy.take_knockback) {
        if (_was_telegraph) {
            scr_enemy_attack_windup_visuals();
        }
        return { landed: true, intercepted: false, armored_chip: true, super_armor: false };
    }

    if (!_was_telegraph) {
        image_blend = c_white;
        telegraph_shake_x = 0;
        telegraph_shake_y = 0;
    }

    if (_policy.take_stun) {
        if (state == ENEMY_STATE.STUNNED && stunTimer > 0) {
            return { landed: true, intercepted: false, armored_chip: false, super_armor: false };
        }

        var _poise_on = (variable_instance_exists(id, "enemy_poise_timer") && enemy_poise_timer > 0
            && state != ENEMY_STATE.TELEGRAPH && state != ENEMY_STATE.ATTACK);
        if (_poise_on && _combo_count < 2) {
            return { landed: true, intercepted: false, armored_chip: true, super_armor: false };
        }

        enemy_poise_timer = 0;
        state = ENEMY_STATE.STUNNED;
        stunTimer = (_combo_count >= 2) ? other.ENEMY_STUN_AFTER_HIT2 : other.ENEMY_STUN_AFTER_HIT1;

        if (_combo_count >= 2) {
            attack_cooldown = max(attack_cooldown, enemy_post_hit_cooldown_frames);
        } else {
            var _light_cd = (variable_instance_exists(id, "enemy_post_hit_cooldown_light")
                ? enemy_post_hit_cooldown_light : 8);
            attack_cooldown = max(attack_cooldown, _light_cd);
        }
    }

    if (_policy.take_knockback) {
        var _poise_kb = (variable_instance_exists(id, "enemy_poise_timer") && enemy_poise_timer > 0
            && state != ENEMY_STATE.TELEGRAPH && state != ENEMY_STATE.ATTACK);
        if (_poise_kb && _combo_count < 2) {
            return { landed: true, intercepted: false, armored_chip: true, super_armor: false };
        }

        var _pcx = (other.bbox_left + other.bbox_right) * 0.5;
        var _ecx = (bbox_left + bbox_right) * 0.5;
        var _knockback_dir = sign(_ecx - _pcx);
        if (_knockback_dir == 0) _knockback_dir = other.last_direction;

        var _kb = (_combo_count >= 2) ? other.ATTACK_FINISHER_KNOCKBACK_X : other.ATTACK_LIGHT_KNOCKBACK;
        knockback_pending_x = _knockback_dir * _kb;
        knockback_pending_y = 0;
        knockback_pending_lift = false;
        knockbackX = knockback_pending_x;
        hsp = knockbackX;
    }

    return { landed: true, intercepted: false, armored_chip: false, super_armor: false };
}

/// @function scr_enemy_attack_windup_visuals
function scr_enemy_attack_windup_visuals() {
    image_blend = make_color_rgb(255, 72, 88);
    telegraph_shake_x = random_range(-2.5, 2.5);
    telegraph_shake_y = random_range(-1.5, 1.5);
}

/// @function scr_enemy_wall_impact_feedback
/// @description Screen shake + crystal spark burst when attack hits a wall.
function scr_enemy_wall_impact_feedback() {
    scr_camera_trigger_shake(5, 10);
    scr_enemy_impact_spark_burst(x, y - 8);
    scr_hitstop_trigger(2);
}

/// @function scr_enemy_impact_spark_burst
function scr_enemy_impact_spark_burst(_cx, _cy) {
    if (!variable_instance_exists(id, "impact_spark_list")) impact_spark_list = [];
    repeat (8) {
        array_push(impact_spark_list, scr_crystal_spark_create(_cx, _cy));
    }
}

/// @function scr_enemy_impact_spark_step
function scr_enemy_impact_spark_step() {
    if (!variable_instance_exists(id, "impact_spark_list")) return;
    for (var _i = array_length(impact_spark_list) - 1; _i >= 0; _i--) {
        impact_spark_list[_i].life--;
        if (impact_spark_list[_i].life <= 0) {
            array_delete(impact_spark_list, _i, 1);
        }
    }
}

/// @function scr_enemy_impact_spark_draw
function scr_enemy_impact_spark_draw() {
    if (!variable_instance_exists(id, "impact_spark_list")) return;
    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    gpu_set_blendmode(bm_add);
    for (var _i = 0; _i < array_length(impact_spark_list); _i++) {
        var _s = impact_spark_list[_i];
        var _t = _s.life / max(1, _s.max_life);
        var _rad = _s.radius + lengthdir_y(_s.wobble_amp, _s.wobble_phase);
        var _px = _s.cx + lengthdir_x(_rad, _s.angle);
        var _py = _s.cy + lengthdir_y(_rad, _s.angle);
        draw_set_color(c_white);
        draw_set_alpha(BULB_CRYSTAL_SPARK_ALPHA * _t);
        draw_circle(_px, _py, _s.size, false);
    }
    gpu_set_blendmode(_old_blend);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
}

/// @function scr_enemy_ai
/// @description Direct PATROL → CHASE → TELEGRAPH → ATTACK → RECOIL loop (+ STUNNED on player hit).
function scr_enemy_ai() {
    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);

    if (!instance_exists(obj_player)) {
        hsp = 0;
        return;
    }

    var _dir = scr_enemy_dir_toward_player();
    var _hgap = scr_enemy_hgap_to_player();
    var _dist_total = point_distance(x, y, obj_player.x, obj_player.y);
    var _melee_band = scr_enemy_melee_telegraph_hgap_max();

    switch (state) {
        case ENEMY_STATE.PATROL:
            scr_enemy_ai_patrol_core();
            break;

        case ENEMY_STATE.NOTICE: {
            hsp = 0;
            vsp = 0;
            image_yscale = base_yscale;
            scr_enemy_notice_visuals();
            if (_dir != 0) scr_enemy_set_facing(_dir);

            var _los_clear = scr_enemy_dual_los_clear();
            if (!_los_clear || _dist_total > chaseRange * 1.2) {
                scr_enemy_patrol_drop_aggro();
                break;
            }

            state_timer--;
            if (state_timer <= 0) {
                state = ENEMY_STATE.CHASE;
                image_blend = c_white;
                lost_los_timer = 0;
                chase_path_blocked_timer = 0;
                hsp = 0;
            }
        } break;

        case ENEMY_STATE.CHASE: {
            scr_enemy_ai_patrol_core();
            if (state != ENEMY_STATE.CHASE) break;

            image_blend = c_white;

            // Contact braking — only telegraph when dash can actually reach the player.
            if (_hgap <= _melee_band) {
                hsp = 0;
                if (attack_cooldown <= 0 && scr_enemy_dual_los_clear()
                    && !scr_enemy_player_above_unreachable()) {
                    scr_enemy_begin_telegraph();
                }
                break;
            }

            // Keep closing until tight telegraph range (don't stop in the wide approach zone).
            if (_dir != 0) {
                hsp = scr_enemy_chase_hsp_for_distance(_hgap, _dir);
                if (variable_instance_exists(id, "enemy_poise_timer") && enemy_poise_timer > 0) {
                    var _mult = (variable_instance_exists(id, "enemy_poise_chase_mult") ? enemy_poise_chase_mult : 1.35);
                    hsp *= _mult;
                }
            }
        } break;

        case ENEMY_STATE.TELEGRAPH: {
            // Fully committed tell — baiting (circle, jump, brief LOS) cannot cancel the windup.
            hsp = 0;
            image_yscale = base_yscale;
            scr_enemy_attack_windup_visuals();
            var _commit = (variable_instance_exists(id, "telegraph_commit_dir") && telegraph_commit_dir != 0)
                ? telegraph_commit_dir : scr_enemy_facing_sign();
            if (_commit != 0) scr_enemy_set_facing(_commit);

            state_timer--;
            if (state_timer <= 0) {
                scr_enemy_begin_attack_dash();
            }
        } break;

        case ENEMY_STATE.ATTACK: {
            image_yscale = base_yscale;
            var _dash_face = sign(hsp);
            if (_dash_face == 0) {
                _dash_face = (variable_instance_exists(id, "telegraph_commit_dir") && telegraph_commit_dir != 0)
                    ? telegraph_commit_dir : scr_enemy_facing_sign();
            }
            if (_dash_face != 0) scr_enemy_set_facing(_dash_face);
        } break;

        case ENEMY_STATE.RECOIL: {
            hsp = 0;
            image_yscale = base_yscale;
            image_blend = make_color_rgb(248, 252, 255); // white recovery tint
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;

            state_timer--;
            if (state_timer <= 0) {
                attack_cooldown = attack_cooldown_max_frames;
                image_blend = c_white;
                state = ENEMY_STATE.CHASE;
                lost_los_timer = 0;
                chase_path_blocked_timer = 0;
                attack_frame = 0;
            }
        } break;

        case ENEMY_STATE.STUNNED:
            // Velocity handled in obj_enemy Step (knockback slide + gravity).
            break;
    }

    if (global.show_debug) {
        show_debug_message("Enemy ENEMY_STATE: " + string(state) + " | HGap: " + string(_hgap) + " | hsp: " + string(hsp));
    }
}

/// @function scr_enemy_patrol_reanchor_here
function scr_enemy_patrol_reanchor_here() {
    home_x = clamp(x, 48, room_width - 48);
    spawn_x = home_x;
}

/// @function scr_enemy_los_to_player
/// @description Dual center + feet raycast (delegates to scr_enemy_raycast).
function scr_enemy_los_to_player() {
    return scr_enemy_dual_los_clear();
}

/// @function scr_enemy_attack_wall_probe
/// @returns {Bool} True if forward ray hits solid tile or obj_solid.
function scr_enemy_attack_wall_probe() {
    if (hsp == 0) return false;
    var _dir = sign(hsp);
    var _x1 = (_dir > 0) ? bbox_right : bbox_left;
    var _y1 = (bbox_top + bbox_bottom) * 0.5;
    var _x2 = _x1 + _dir * 14;
    if (collision_line(_x1, _y1, _x2, _y1, obj_solid, true, true) != noone) return true;
    if (check_tile_collision(_x2, _y1) || check_tile_collision(_x2, bbox_bottom - 4)) return true;
    return false;
}
