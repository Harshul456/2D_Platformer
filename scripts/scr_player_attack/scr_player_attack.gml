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
    image_index = 0;
    comboTimer = comboCooldown;
    attack_priority_timer = 14; // Startup priority — does not beat enemy telegraph armor or super-armor dash

    switch (comboCount) {
        case 1:
            hsp = last_direction * 3;
            sprite_index = spr_asta_attack1;
            image_blend = c_white;
            break;
        case 2:
            hsp = last_direction * 3.5;
            sprite_index = spr_mc_attack2;
            image_blend = c_lime;
            break;
        case 3:
            hsp = last_direction * 5;
            sprite_index = spr_asta_attack1;
            image_blend = c_aqua;
            break;
    }
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
    debug_hitbox_active = false;
}