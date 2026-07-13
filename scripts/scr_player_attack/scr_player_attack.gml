/// @description Apply held left/right to facing when a new swing starts (allows 1→2 turn-around).
function scr_player_apply_attack_facing() {
    var _dir = key_right - key_left;
    if (_dir != 0) {
        last_direction = _dir;
        image_xscale = last_direction * image_base_scale;
    }
}

function scr_player_attack() {
    if (!grounded) return;

    if (attacking) {
        if (image_index > image_number * 0.4) combo_buffer = true;
        return;
    }

    // Only valid mid-combo step is 1→2 (no third hit from buffer/timer).
    if (comboTimer > 0 && comboCount == 1) comboCount = 2;
    else comboCount = 1;

    scr_player_apply_attack_facing();

    attacking = true;
    combo_buffer = false;
    attack_chain_latched = false;
    attack_has_hit = false;
    attack_recovery_cut = false;
    image_index = 0;
    comboTimer = comboCooldown;
    attack_priority_timer = 14; // Startup priority — does not beat enemy telegraph armor or super-armor dash
    scr_player_saber_trail_clear();

    switch (comboCount) {
        case 1:
            hsp = last_direction * 3;
            sprite_index = spr_asta_attack1;
            image_blend = c_white;
            attack_commit_lock = 0;
            break;
        case 2:
            scr_player_apply_attack_facing();
            var _lunge = (variable_instance_exists(id, "ATTACK2_COMBO_LUNGE_HSP") ? ATTACK2_COMBO_LUNGE_HSP : 5.5);
            hsp = last_direction * _lunge;
            sprite_index = spr_mc_attack2;
            image_blend = c_lime;
            attack_commit_lock = (variable_instance_exists(id, "ATTACK2_COMMIT_LOCK_FRAMES")
                ? ATTACK2_COMMIT_LOCK_FRAMES : 28);
            break;
        case 3:
            hsp = last_direction * 5;
            sprite_index = spr_asta_attack1;
            image_blend = c_aqua;
            attack_commit_lock = 0;
            break;
    }
}

/// @function scr_player_attack1_prepare_retreat
/// @description Solo atk1 hit — early endlag + retreat; chain intent keeps forward lean.
function scr_player_attack1_prepare_retreat() {
    if (comboCount != 1) return;

    attack_shift_remaining = 0;

    if (attack_chain_latched) {
        var _spd = (variable_instance_exists(id, "ATTACK_COMBO_CONTINUE_HSP") ? ATTACK_COMBO_CONTINUE_HSP : 3.5);
        if (last_direction != 0) {
            hsp = last_direction * _spd;
            runMomentum = 0;
        }
        return;
    }

    attack_recovery_cut = true;

    var _dir = key_right - key_left;
    if (_dir == 0) _dir = -last_direction;
    if (_dir == 0) _dir = -sign(image_xscale);
    if (_dir != 0) {
        var _spd = (variable_instance_exists(id, "ATTACK1_HIT_RETREAT_HSP") ? ATTACK1_HIT_RETREAT_HSP : 4);
        hsp = _dir * _spd;
        runMomentum = 0;
    }
}

/// @function scr_player_attack_end_swing
/// @param {Real} [_post_accel_frames]
function scr_player_attack_end_swing(_post_accel_frames) {
    if (argument_count < 1) {
        _post_accel_frames = (variable_instance_exists(id, "POST_ATTACK_ACCEL_FRAMES") ? POST_ATTACK_ACCEL_FRAMES : 12);
    }

    var _keep_combo_window = (comboCount == 1 && comboTimer > 0);
    var _was_atk2 = (comboCount >= 2);

    attacking = false;
    attack_lockout = 0;
    attack_commit_lock = 0;
    image_blend = c_white;
    attack_recovery_cut = false;
    debug_hitbox_active = false;

    // Atk1 poke: almost zero recovery grace. Atk2: recovery_lock handles commitment.
    attack_recovery_grace = 0;

    if (!_keep_combo_window) {
        attack_buffer_timer = 0;
        attack_chain_buffer_timer = 0;
        attack_chain_latched = false;
        comboCount = 0;
        comboTimer = 0;
    }

    post_attack_accel_timer = _post_accel_frames;

    if (_was_atk2) {
        attack_recovery_lock = (variable_instance_exists(id, "ATTACK2_RECOVERY_LOCK_FRAMES")
            ? ATTACK2_RECOVERY_LOCK_FRAMES : 18);
    }

    if (_keep_combo_window && attack_chain_latched) {
        attack_chain_latched = false;
        scr_player_attack();
        if (!attack_no_lunge) {
            attack_shift_remaining = (variable_instance_exists(id, "ATTACK_SHIFT_PX_2") ? ATTACK_SHIFT_PX_2 : 5);
        }
    }
}

/// @function scr_player_attack_is_recovery_locked
/// @description True when post-atk2 recovery blocks sprint/dash.
function scr_player_attack_is_recovery_locked() {
    return (variable_instance_exists(id, "attack_recovery_lock") && attack_recovery_lock > 0);
}

/// @function scr_player_attack_can_dodge_cancel
/// @description Atk1 poke only — dash away mid-swing; atk2 finisher is committed.
function scr_player_attack_can_dodge_cancel() {
    if (!attacking || !grounded || stunTimer > 0) return false;
    if (comboCount >= 2) return false;
    if (variable_instance_exists(id, "attack_commit_lock") && attack_commit_lock > 0) return false;
    var _min_idx = (variable_instance_exists(id, "DODGE_CANCEL_MIN_INDEX") ? DODGE_CANCEL_MIN_INDEX : 1);
    return (image_index >= _min_idx) || attack_recovery_cut;
}

/// @function scr_player_attack_dodge_cancel
/// @description Cancel atk1 into sprint burst — poke-and-run.
/// @param {Real} _dir Horizontal dash direction (−1 / +1).
function scr_player_attack_dodge_cancel(_dir) {
    if (_dir == 0) return;

    attacking = false;
    attack_lockout = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
    attack_recovery_cut = false;
    attack_shift_remaining = 0;
    attack_has_hit = false;
    attack_recovery_grace = 0;
    attack_priority_timer = 0;
    attack_commit_lock = 0;
    attack_recovery_lock = 0;
    comboCount = 0;
    comboTimer = 0;
    combo_buffer = false;
    post_attack_accel_timer = 0;
    debug_hitbox_active = false;
    image_blend = c_white;

    last_direction = _dir;
    image_xscale = _dir * image_base_scale;

    sprint_committed = true;
    sprint_hold_latched = true;
    sprint_burst_tick = 0;
    sprint_commit_dir = _dir;
    sprint_reel_pending = false;
    sprint_reel_dir_wait = 0;
    sprint_dir_gap = 0;
    sprint_z_idle_charged = false;
    sprint_resume_hold = false;
    sprint_squash_coil_frames = 1;
    is_sprinting = true;
    sprint_jump_carry = false;
    sprint_air_trail = false;
    sprint_reel_active = false;

    var _burst_sp = (variable_instance_exists(id, "SPRINT_BURST_SPEED") ? SPRINT_BURST_SPEED : runsp);
    hsp = _burst_sp * _dir;
    runMomentum = hsp;

    sprite_index = spr_mc_sprint;
    image_index = 0;
    image_speed = 1;
}

/// @function scr_player_is_attack_active
/// @description Active hitbox frames (subimages 1–3).
function scr_player_is_attack_active() {
    return attacking && image_index >= ATTACK_HIT_ACTIVE_START_INDEX && image_index <= 3;
}

/// @function scr_player_has_attack_priority
/// @description True while swing should win trades vs enemy dash contact.
function scr_player_has_attack_priority() {
    return (attack_priority_timer > 0) || scr_player_is_attack_active();
}

/// @function scr_player_is_downward_air_strike
/// @description True when airborne and falling (nail down-strike / pogo window).
function scr_player_is_downward_air_strike() {
    return !grounded && vsp > 0.25;
}

/// @function scr_player_apply_nail_pogo
/// @description Hollow Knight nail-bounce: upward recoil + movement reset.
function scr_player_apply_nail_pogo() {
    vsp = -stomp_force;
    hsp *= 0.35;
    grounded = false;
    jump_count = 0;
    air_chain_jump_used = false;
    coyote_time_timer = 0;
    attacking = false;
    attack_lockout = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
    attack_shift_remaining = 0;
    attack_has_hit = true;
    combo_buffer = false;
    comboTimer = 0;
    comboCount = 0;
    attack_commit_lock = 0;
    attack_recovery_lock = 0;
    attack_recovery_cut = false;
    debug_hitbox_active = false;
}
