// --- obj_enemy STEP EVENT ---
// Intentionally no event_inherited(): parent Step runs scr_enemy_grounded_step (tilemap FSM only).
// This object keeps the full scr_enemy_ai + state machine; Create still inherits parent defaults (tilemap, gnd_*).

if (hit_pressure_timer > 0) {
    hit_pressure_timer--;
    if (hit_pressure_timer <= 0) hit_pressure_hits = 0;
}

if (state != STATE_ATTACK && attack_cooldown > 0) attack_cooldown--;
if (decision_cooldown_timer > 0) decision_cooldown_timer--;
if (pressure_window_timer > 0) {
    pressure_window_timer--;
    if (pressure_window_timer <= 0) pressure_hit_count = 0;
}

// Apply pending knockback after hitstop ends
if (global.hitstop == 0 && (knockback_pending_x != 0 || knockback_pending_y != 0)) {
    // ALWAYS apply horizontal knockback
    knockbackX = knockback_pending_x;
    
    // Apply vertical knockback and lift
    if (knockback_pending_lift) {
        y -= FINISHER_LIFT_OFFSET;
        vsp = knockback_pending_y;
        knockback_pending_lift = false;
    } else if (knockback_pending_y != 0) {
        vsp = knockback_pending_y;
    }
    
    // Clear pending knockback
    knockback_pending_x = 0;
    knockback_pending_y = 0;
}

// 1. INPUT & VELOCITY LOGIC
if (state == STATE_STUNNED) {
    stunTimer--;
    hsp = knockbackX;
    vsp += grv; 
    knockbackX *= 0.85; 
    if (stunTimer <= 0) {
        knockbackX = 0;
        hsp = 0;
        // After any hitstun: pressure via AGGRESSIVE (threat pipeline) — no guaranteed instant red swing
        // (old finisher+close snapped to STATE_ATTACK every time hit 2 landed in range).
        state = STATE_AGGRESSIVE;
        aggressive_timer = aggressive_timer_max;
        if (last_hit_was_finisher) {
            var _px = instance_exists(obj_player) ? abs(obj_player.x - x) : 9999;
            if (_px < retaliation_range_x) {
                aggressive_timer += irandom_range(20, 42);
                threat_next_roll_retreat_bias = true;
            }
        }
        chase_path_blocked_timer = 0;
        attack_phase = 0;
        attack_phase_timer = 0;
        attack_hit_dealt = false;
        was_in_attack_threat_zone = false;
        last_hit_was_finisher = false;
    }
} else {
    scr_enemy_ai();
    vsp += grv; 
}

// 2. ACTUAL TILE MOVEMENT (Pixel-Perfect Snap)
// --- Horizontal Collision ---
if (hsp != 0) {
    var _bbox_side = (hsp > 0) ? bbox_right : bbox_left;
    
    // Check if the total movement is clear
    if (!check_tile_collision(_bbox_side + hsp, bbox_top + 4) && 
        !check_tile_collision(_bbox_side + hsp, bbox_bottom - 4)) {
        x += hsp;
    } else {
        // Snap to wall: Move 1 pixel at a time until contact
        var _step_h = sign(hsp);
        repeat(abs(ceil(hsp))) {
            _bbox_side = (_step_h > 0) ? bbox_right : bbox_left;
            if (!check_tile_collision(_bbox_side + _step_h, bbox_top + 4) && 
                !check_tile_collision(_bbox_side + _step_h, bbox_bottom - 4)) {
                x += _step_h;
            } else {
                hsp = 0;
                knockbackX = 0;
                break;
            }
        }
    }
}

// Cornered retreat: wanted horizontal retreat but wall zeroed hsp — snap to aggressive wind-up instead of burning timer.
if (state == STATE_DEFENSIVE_RETREAT && retreat_timer > 0) {
    if (abs(retreat_intended_hsp) > 0.05 && abs(hsp) < 0.05) {
        retreat_wall_stall++;
        if (retreat_wall_stall >= enemy_retreat_cornered_stall_frames) {
            state = STATE_ATTACK;
            attack_phase = 0;
            attack_phase_timer = enemy_attack_windup_frames;
            attack_hit_dealt = false;
            retreat_timer = 0;
            retreat_wall_stall = 0;
            retreat_intended_hsp = 0;
            hsp = 0;
            was_in_attack_threat_zone = true;
            last_branch_was_retreat = false;
            scr_enemy_attack_windup_visuals();
        }
    } else {
        retreat_wall_stall = 0;
    }
} else {
    retreat_wall_stall = 0;
}

// --- Vertical Collision ---
var _bbox_v = (vsp >= 0) ? bbox_bottom : bbox_top;
if (!check_tile_collision(bbox_left + 2, _bbox_v + vsp) && 
    !check_tile_collision(bbox_right - 2, _bbox_v + vsp)) {
    y += vsp;
} else {
    // Snap to floor/ceiling 1 pixel at a time
    var _step_v = sign(vsp);
    repeat(abs(ceil(vsp))) {
        _bbox_v = (_step_v >= 0) ? bbox_bottom : bbox_top;
        if (!check_tile_collision(bbox_left + 2, _bbox_v + _step_v) && 
            !check_tile_collision(bbox_right - 2, _bbox_v + _step_v)) {
            y += _step_v;
        } else {
            vsp = 0;
            break;
        }
    }
}

// --- ENEMY HIT BLINK ---
if (hit_blink_timer > 0) {
    hit_blink_timer--;
    
    // Toggle alpha every 4 frames for a fast flicker
    if (hit_blink_timer % 4 == 0) {
        if (image_alpha == 1) image_alpha = 0.4;
        else image_alpha = 1;
    }
} else {
    image_alpha = 1;
}

// 3. PIXEL SNAP
x = round(x);
y = round(y);

// Attack dash: one hit after movement. Sweep catches the frame motion crosses the player; telegraph stays no damage.
// Include first recovery frame — AI can move to phase 2 same frame as the last dash step.
var _dash_hit_frame = (attack_phase == 1)
    || (attack_phase == 2 && attack_phase_timer == enemy_attack_recovery_frames);
if (state == STATE_ATTACK && _dash_hit_frame && !attack_hit_dealt && instance_exists(obj_player)) {
    var _yc = (bbox_top + bbox_bottom) * 0.5;
    var _contact = place_meeting(x, y, obj_player)
        || (collision_line(dash_sweep_prev_x, _yc, x, _yc, obj_player, true, true) != noone);
    // One hit per dash (attack_hit_dealt). Do not gate on i-frames — otherwise overlap blinks while
    // invincible, then the player walks/dashes away before damage; knockback must use stun/knockBackX
    // or scr_player_movement overwrites hsp the same frame.
    var _pl = obj_player;
    var _startup_prio = instance_exists(_pl) && ((_pl.attack_priority_timer > 0)
        || (_pl.attacking && _pl.image_index < _pl.ATTACK_HIT_ACTIVE_START_INDEX));
    if (_contact && !_startup_prio) {
        with (obj_player) {
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
            attack_shift_remaining = 0;
            combo_buffer = false;
            comboTimer = 0;
            comboCount = 0;
            debug_hitbox_active = false;
            is_dashing = false;
            dash_timer = 0;
            invincible = true;
            invincibleTimer = INVINCIBILITY_FRAMES;
            attack_priority_timer = 0;
        }
        attack_hit_dealt = true;
    }
}