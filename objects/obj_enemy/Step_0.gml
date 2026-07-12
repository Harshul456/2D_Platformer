// --- obj_enemy STEP — Hollow Knight crystal FSM (scr_enemy_ai + tile movement) ---
// Parent Step runs scr_enemy_grounded_step; this object overrides with HK behaviour.

var _hitstop_frozen = (global.hitstop > 0);
var _step_prev_x = x;

if (!_hitstop_frozen) {
    if (state != ENEMY_STATE.ATTACK && attack_cooldown > 0) attack_cooldown--;

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
        vsp += grv;
    }

    if (enemy_ai_enabled && state == ENEMY_STATE.ATTACK) {
        dash_sweep_prev_x = _step_prev_x;
        attack_frame++;
        if (scr_enemy_attack_wall_probe()) {
            hsp = 0;
            state = ENEMY_STATE.RECOIL;
            state_timer = enemy_recover_frames;
            image_blend = c_white;
            scr_enemy_wall_impact_feedback();
        } else if (attack_frame >= enemy_attack_dash_frames) {
            hsp = 0;
            state = ENEMY_STATE.RECOIL;
            state_timer = enemy_recover_frames;
            image_blend = c_white;
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

    // Chase: walled + LOS lost — drop aggro (never while player is still visible, that caused facing snap).
    if (enemy_ai_enabled && state == ENEMY_STATE.CHASE && instance_exists(obj_player)) {
        var _toward = scr_enemy_dir_toward_player();
        var _los_blocked = !scr_enemy_dual_los_clear();
        if (_los_blocked && _toward != 0
            && abs(_hsp_before_move) > 0.01 && abs(x - _x_before_move) < 0.01
            && sign(_hsp_before_move) == _toward) {
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
}
