/// Lean Hollow Knight-style enemy FSM (replaces legacy threat pipeline / branch rolls).

enum ENEMY_STATE {
    PATROL,
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

/// @function scr_enemy_melee_band
/// @returns {Real} Horizontal standoff distance before melee telegraph.
function scr_enemy_melee_band() {
    if (!instance_exists(obj_player)) return 9999;
    var _ehw = (bbox_right - bbox_left) * 0.5;
    var _phw = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
    return (_ehw + _phw) + chase_stop_extra;
}

/// @function scr_enemy_player_in_melee_band
function scr_enemy_player_in_melee_band() {
    if (!instance_exists(obj_player)) return false;
    return abs(obj_player.x - x) <= scr_enemy_melee_band();
}

/// @function scr_enemy_touching_solid_wall
function scr_enemy_touching_solid_wall() {
    if (place_meeting(x, y, obj_solid)) return true;
    var _cy = (bbox_top + bbox_bottom) * 0.5;
    return check_tile_collision(bbox_left - 1, _cy) || check_tile_collision(bbox_right + 1, _cy);
}

/// @function scr_enemy_begin_telegraph
/// @description Contact braking → mandatory 15-frame warning (no damage sweep).
function scr_enemy_begin_telegraph() {
    state = ENEMY_STATE.TELEGRAPH;
    state_timer = enemy_telegraph_frames;
    hsp = 0;
    attack_hit_dealt = false;
    attack_frame = 0;
    dash_sweep_prev_x = x;
    if (instance_exists(obj_player)) {
        scr_enemy_set_facing(scr_enemy_dir_toward_player());
    }
    scr_enemy_attack_windup_visuals();
}

/// @function scr_enemy_begin_attack_dash
/// @description Locked launch after telegraph expires — dash hsp + sweep armed next Step.
function scr_enemy_begin_attack_dash() {
    var _dir = instance_exists(obj_player) ? scr_enemy_dir_toward_player() : scr_enemy_facing_sign();
    if (_dir == 0) _dir = scr_enemy_facing_sign();
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
/// @description HK-style punish: back off to CHASE with re-engage cooldown (no instant counter-telegraph).
function scr_enemy_post_stun_recovery() {
    knockbackX = 0;
    hsp = 0;
    state = ENEMY_STATE.CHASE;
    lost_los_timer = 0;
    chase_path_blocked_timer = 0;
    attack_hit_dealt = false;
    attack_frame = 0;
    image_blend = c_white;
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;
    attack_cooldown = enemy_post_hit_cooldown_frames;
}

/// @function scr_enemy_chase_hsp_for_distance
/// @description Slower creep inside approach zone — aggro outside nail range (HK bait spacing).
function scr_enemy_chase_hsp_for_distance(_hgap, _dir, _melee_band) {
    if (_dir == 0 || _hgap <= _melee_band) return 0;
    var _hsp = _dir * moveSpeed;
    if (_hgap < _melee_band * enemy_approach_slow_mult) {
        _hsp *= enemy_approach_slow_factor;
    }
    return _hsp;
}

/// @function scr_enemy_on_player_hit
/// @description Armor + stun resolution when the player attack connects (call inside with enemy).
/// @param {Real} _combo_count Player combo step (1 or 2).
function scr_enemy_on_player_hit(_combo_count) {
    hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
    obj_enemy_health -= other.ATTACK_DAMAGE_PER_HIT;

    // Super armor — finish dash sweep; no stun, no knockback.
    if (state == ENEMY_STATE.ATTACK) return;

    // TELEGRAPH is punishable — HK-style: nail into the tell wins the exchange.

    image_blend = c_white;
    telegraph_shake_x = 0;
    telegraph_shake_y = 0;

    state = ENEMY_STATE.STUNNED;
    stunTimer = (_combo_count >= 2) ? other.ENEMY_STUN_AFTER_HIT2 : other.ENEMY_STUN_AFTER_HIT1;

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
    var _melee_band = scr_enemy_melee_band();

    switch (state) {
        case ENEMY_STATE.PATROL:
            scr_enemy_ai_patrol_core();
            break;

        case ENEMY_STATE.CHASE: {
            scr_enemy_ai_patrol_core();
            if (state != ENEMY_STATE.CHASE) break;

            image_blend = c_white;

            // Contact braking — entering melee band: stop, then telegraph (never same-frame hit).
            if (_hgap <= _melee_band) {
                hsp = 0;
                if (attack_cooldown <= 0 && scr_enemy_dual_los_clear()) {
                    scr_enemy_begin_telegraph();
                }
                break;
            }

            // Approach slow inside bait zone (patrol_core sets full speed; taper near nail range).
            if (_dir != 0) {
                hsp = scr_enemy_chase_hsp_for_distance(_hgap, _dir, _melee_band);
            }
        } break;

        case ENEMY_STATE.TELEGRAPH: {
            // 2. Telegraph warning — frozen feet, red flash, shake; zero damage.
            hsp = 0;
            image_yscale = base_yscale;
            scr_enemy_attack_windup_visuals();
            if (_dir != 0) scr_enemy_set_facing(_dir);

            state_timer--;
            if (state_timer <= 0) {
                // 3. Locked attack launch — dash + sweep only from this frame onward.
                scr_enemy_begin_attack_dash();
            }
        } break;

        case ENEMY_STATE.ATTACK: {
            image_yscale = base_yscale;
            if (_dir != 0) scr_enemy_set_facing(sign(hsp) != 0 ? sign(hsp) : _dir);
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
