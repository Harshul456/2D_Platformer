// --- obj_enemy STEP — Hollow Knight crystal FSM (scr_enemy_ai + tile movement) ---
// Parent Step runs scr_enemy_grounded_step; this object overrides with HK behaviour.

// Explosive death takes over completely — freeze/flash then shatter (ticks through hitstop).
if (state == ENEMY_STATE.DEATH) {
    scr_enemy_death_step();
    exit;
}

var _hitstop_frozen = (global.hitstop > 0);
var _time_frozen = !_hitstop_frozen && !scr_time_scale_should_tick();
var _step_prev_x = x;

if (_time_frozen) {
    // Slow-mo: skip AI/physics this frame; anims hold via image_speed elsewhere.
    exit;
}

if (!_hitstop_frozen) {
    if (state != ENEMY_STATE.ATTACK && attack_cooldown > 0) attack_cooldown--;
    if (variable_instance_exists(id, "armor_deflect_cooldown") && armor_deflect_cooldown > 0) {
        armor_deflect_cooldown--;
    }
    if (variable_instance_exists(id, "enemy_poise_timer") && enemy_poise_timer > 0) {
        enemy_poise_timer--;
    }

    if (enemy_ai_enabled && (knockback_pending_x != 0 || knockback_pending_y != 0)) {
        knockbackX = knockback_pending_x;
        if (knockback_pending_lift) {
            y -= FINISHER_LIFT_OFFSET;
            vsp = knockback_pending_y;
            knockback_pending_lift = false;
        } else if (knockback_pending_y != 0) {
            vsp = knockback_pending_y;
        }
        knockback_pending_x = 0;
        knockback_pending_y = 0;
    }

    if (!enemy_ai_enabled) {
        hsp = 0;
        vsp = 0;
        knockbackX = 0;
    } else if (state == ENEMY_STATE.STUNNED) {
        stunTimer--;
        hsp = knockbackX;
        vsp += grv;
        knockbackX *= 0.85;
        if (stunTimer <= 0) {
            scr_enemy_post_stun_recovery();
        }
    } else {
        scr_enemy_ai();
        if (state == ENEMY_STATE.NOTICE || state == ENEMY_STATE.TELEGRAPH) {
            hsp = 0;
            if (enemy_grounded) vsp = 0;
        } else {
            vsp += grv;
        }
    }

    // Hard freeze during alert / attack tell — no drift from movement solver.
    if (state == ENEMY_STATE.NOTICE || state == ENEMY_STATE.TELEGRAPH) {
        hsp = 0;
        if (enemy_grounded) vsp = 0;
    }

    if (enemy_ai_enabled && state == ENEMY_STATE.ATTACK) {
        dash_sweep_prev_x = _step_prev_x;
        attack_frame++;
        // Resolve the slash BEFORE the forward wall probe. When the player is pinned against a wall the
        // probe trips on that same wall (just behind the player) on the exact frame the hitbox goes
        // active, recoiling the enemy so the hit never registered — the screen still shook from the
        // wall bonk, but the player took no damage and never flinched. Landing the hit first fixes that;
        // a successful hit already zeroes hsp + switches to RECOIL, so the probe below won't re-fire.
        scr_enemy_resolve_attack_player_contact();
        if (state == ENEMY_STATE.ATTACK) {
            // Is the player pinned in the dash path (between us and the wall)? A wall bonk should only
            // happen on a genuine whiff — if the player is cornered against the wall we must keep
            // dashing so the attack reaches its active hitbox frames and actually connects. Otherwise
            // the forward probe trips on the wall behind the player during attack startup (before any
            // hitbox is active) and recoils us instantly: screen shakes, but the player is never hit
            // and the attack animation barely plays.
            var _pin_dir = sign(hsp);
            if (_pin_dir == 0) _pin_dir = scr_enemy_facing_sign();
            if (_pin_dir == 0) _pin_dir = 1;
            // Cover the WHOLE enemy body plus a forward reach — not just a strip ahead of the leading
            // edge — so a player who is overlapping the enemy (both jammed into the same corner) counts
            // as "in the path" too. A thin front-only strip misses an overlapping player and the wall
            // bonk fires anyway.
            var _pin_reach = 22;
            var _pin_x1 = (_pin_dir > 0) ? bbox_left : bbox_left - _pin_reach;
            var _pin_x2 = (_pin_dir > 0) ? bbox_right + _pin_reach : bbox_right;
            var _player_in_path = (instance_exists(obj_player)
                && collision_rectangle(_pin_x1, bbox_top - 4, _pin_x2, bbox_bottom, obj_player, false, true) != noone);

            if (scr_enemy_attack_wall_probe() && !_player_in_path) {
                hsp = 0;
                state = ENEMY_STATE.RECOIL;
                state_timer = (attack_hit_dealt ? enemy_recover_frames : enemy_recover_frames_whiff);
                image_blend = c_white;
                scr_enemy_wall_impact_feedback();
                if (scr_enemy_player_above_unreachable()) {
                    attack_cooldown = attack_cooldown_max_frames;
                }
            } else if (attack_frame >= enemy_attack_dash_frames) {
                hsp = 0;
                state = ENEMY_STATE.RECOIL;
                state_timer = (attack_hit_dealt ? enemy_recover_frames : enemy_recover_frames_whiff);
                image_blend = c_white;
            }
        }
    }

    var _x_before_move = x;
    var _hsp_before_move = hsp;
    scr_enemy_tile_movement();

    // Patrol: blocked into a wall — flip once, then pause to avoid corner jitter.
    if (enemy_ai_enabled && state == ENEMY_STATE.PATROL) {
        if (patrol_flip_cooldown > 0) patrol_flip_cooldown--;
        if (patrol_flip_cooldown <= 0
            && abs(_hsp_before_move) > 0.01 && abs(x - _x_before_move) < 0.01
            && sign(_hsp_before_move) == patrol_dir) {
            patrol_dir *= -1;
            scr_enemy_set_facing(patrol_dir);
            hsp = 0;
            patrol_flip_cooldown = 15;
        }
    }

    // Chase: walled under a higher ledge — drop aggro (LOS can still be clear over the wall).
    if (enemy_ai_enabled && state == ENEMY_STATE.CHASE && instance_exists(obj_player)) {
        var _toward = scr_enemy_dir_toward_player();
        var _los_blocked = !scr_enemy_dual_los_clear();
        var _above_unreachable = scr_enemy_player_above_unreachable();
        var _wall_under_player = (_toward != 0 && scr_enemy_patrol_wall_ahead(_toward));
        var _stuck_move = (abs(_hsp_before_move) > 0.01 && abs(x - _x_before_move) < 0.01
            && sign(_hsp_before_move) == _toward);
        var _stuck_under_ledge = (_above_unreachable && _wall_under_player
            && (_stuck_move || abs(_hsp_before_move) < 0.01));

        if ((_los_blocked && _stuck_move) || _stuck_under_ledge) {
            chase_wall_stuck_timer++;
            if (chase_wall_stuck_timer >= 15) {
                scr_enemy_patrol_drop_aggro();
                chase_reaggro_cooldown = 48;
            }
        } else {
            chase_wall_stuck_timer = 0;
        }
    }

    scr_enemy_impact_spark_step();
}

if (!_hitstop_frozen && hit_blink_timer > 0) {
    hit_blink_timer--;
    if (hit_blink_timer % 4 == 0) {
        image_alpha = (image_alpha == 1) ? 0.4 : 1;
    }
} else if (!_hitstop_frozen) {
    image_alpha = 1;
}

if (!_hitstop_frozen) {
    x = round(x);
    y = round(y);
}

if (!_hitstop_frozen && enemy_ai_enabled) {
    scr_enemy_resolve_attack_player_contact();
}

if (!_hitstop_frozen) {
    scr_enemy_floating_hover_step();
    if (state == ENEMY_STATE.NOTICE) {
        hsp = 0;
        if (enemy_grounded) vsp = 0;
    }
}

scr_enemy_crystal_light_step();

// Procedural lean — state-driven tilt before the draw pass.
if (enemy_ai_enabled) {
    switch (state) {
        case ENEMY_STATE.PATROL:
            target_angle = -patrol_dir * lean_max_patrol;
            break;

        case ENEMY_STATE.CHASE:
            if (hsp != 0) {
                target_angle = -sign(hsp) * lean_max_chase;
            } else {
                target_angle = 0;
            }
            break;

        default:
            target_angle = 0;
            break;
    }

    lean_angle = lerp(lean_angle, target_angle, lean_lerp_speed);
}

// Combat pose swap + manual scrub — after attack_frame / state_timer updates.
if (!_hitstop_frozen) {
    scr_enemy_update_combat_sprite();
}
