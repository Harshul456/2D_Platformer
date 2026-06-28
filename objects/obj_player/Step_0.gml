// --- IN obj_player STEP EVENT ---

function _player_sprint_deform() {
    // Frame 1 only (Z press): coil squash; every later step while sprinting stays at normal scale.
    if (sprint_squash_coil_frames > 0) {
        sprint_squash_x = SPRINT_SQUASH_COIL_X;
        sprint_squash_y = SPRINT_SQUASH_COIL_Y;
        sprint_squash_coil_frames--;
    } else if (sprint_committed || is_sprinting) {
        sprint_squash_x = 1;
        sprint_squash_y = 1;
    } else {
        sprint_squash_x = lerp(sprint_squash_x, 1, SPRINT_SQUASH_LERP);
        sprint_squash_y = lerp(sprint_squash_y, 1, SPRINT_SQUASH_LERP);
    }
    var _face = sign(image_xscale);
    if (_face == 0) _face = last_direction != 0 ? last_direction : 1;
    image_xscale = _face * image_base_scale * sprint_squash_x;
    image_yscale = image_base_scale * sprint_squash_y;
}

// --- HITSTOP CHECK (at the very start of Step Event) ---
if (scr_hitstop_handler()) {
    _player_sprint_deform(); // Coil/normal scale ticks during hitstop freeze
    exit;
}

if (attack_priority_timer > 0) attack_priority_timer--;

// Stable collision hull: keep hurtbox consistent even while attacking.
// Using the attack sprite as the mask makes the hurtbox include the weapon/extents and feels unfair.
mask_index = spr_mc_idle;

// Toggle reflections while recording (F2)
if (keyboard_check_pressed(vk_f2)) {
    global.reflections_enabled = !global.reflections_enabled;
}

// 1. PROCESS NORMAL MOVEMENT 
scr_player_movement();

// Hits can land after attack Step (collision order) or same frame as knockback — never keep swing physics while stunned.
if (stunTimer > 0 && attacking) {
    attacking = false;
    attack_lockout = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
    combo_buffer = false;
    attack_shift_remaining = 0;
    comboTimer = 0;
    comboCount = 0;
    image_blend = c_white;
    debug_hitbox_active = false;
    attack_priority_timer = 0;
}

// attack_lockout must tick down even if attacking was cleared mid-swing (e.g. enemy hit),
// otherwise section 2 never allows a new attack.
if (attack_lockout > 0) attack_lockout--;

function _attack_step_shift() {
    // Queue a small slide instead of instant teleport.
    if (attack_no_lunge) return;
    attack_shift_remaining = (comboCount == 1) ? ATTACK_SHIFT_PX_1 : ATTACK_SHIFT_PX_2;
}

// 2. PROCESS ATTACK INPUT (with buffer)
// Skip if attacking — let combo transition handle chaining.
// Skip if attack_lockout > 0: prevents starting before current attack finishes.
// Skip if attack_recovery_grace > 0: prevents restarting attack 1 immediately after it ends (see ATTACK_RECOVERY_GRACE)
if (!attacking && stunTimer <= 0 && attack_lockout <= 0 && attack_recovery_grace <= 0 && attack_buffer_timer > 0 && attackCooldownTimer <= 0 && grounded) {
    scr_player_attack(); 
    
    // Start the forward slide on attack 1.
    _attack_step_shift();

    attack_buffer_timer = 0; // Consume the buffer — one press = one attack
    
    // Only reset these if the script actually started a NEW swing
    if (image_index == 0) {
        attackCooldownTimer = attackCooldown;
        attack_has_hit = false; 
        is_sprinting = false;
        sprint_afterimage_tick = 0;
        sprint_jump_carry = false;
        sprint_air_trail = false;
        sprint_reel_active = false;
        sprint_reel_pending = false;
        sprint_committed = false;
        sprint_burst_tick = 0;
        sprint_commit_dir = 0;
        sprint_hold_latched = false;
        sprint_resume_hold = false;
        sprint_dir_gap = 0;
    }
}

// 3. PROCESS THE ATTACK STATE & PHYSICS (stunned = knockback only; no lunge / combo in air)
if (attacking && stunTimer <= 0) {
    // --- STRONGER LUNGE FRICTION ---
    hsp = lerp(hsp, 0, ATTACK_LUNGE_FRICTION);
    if (abs(hsp) < ATTACK_LUNGE_CUTOFF) hsp = 0;
    
    // Optional sustained mid-swing hsp (disabled when ATTACK_COMBO_LUNGE_PER_FRAME is 0 in Create).
    if (ATTACK_COMBO_LUNGE_PER_FRAME != 0) {
        var _lunge_end = image_number * ATTACK_COMBO_LUNGE_FRAME_END;
        if (!attack_has_hit && !attack_no_lunge && image_index >= 1 && image_index <= _lunge_end) {
            var _ld = last_direction;
            hsp += _ld * ATTACK_COMBO_LUNGE_PER_FRAME;
            var _cap = (comboCount >= 2) ? ATTACK_COMBO_LUNGE_MAX_HSP_2 : ATTACK_COMBO_LUNGE_MAX_HSP;
            hsp = clamp(hsp, -_cap, _cap);
        }
    }
    
    // --- STOP ON HIT ---
    if (attack_has_hit) hsp *= ATTACK_ON_HIT_HSLOW;

    // --- FORWARD SLIDE (small, smooth) ---
    if (!attack_no_lunge && attack_shift_remaining > 0) {
        var _step = (last_direction != 0) ? last_direction : (image_xscale >= 0 ? 1 : -1);
        var _n = min(ATTACK_SHIFT_PX_PER_FRAME, attack_shift_remaining);
        repeat (_n) {
            var _cy = floor((bbox_top + bbox_bottom) * 0.5);
            var _side = (_step > 0) ? floor(bbox_right) : floor(bbox_left);
            if (!check_tile_collision(_side + _step, _cy)) {
                x += _step;
                attack_shift_remaining -= 1;
            } else {
                attack_shift_remaining = 0;
                break;
            }
        }
    }
    
    // --- HIT DETECTION ---
    var _is_swinging = (image_index >= 1 && image_index <= 3);
    
    if (_is_swinging && !attack_has_hit) { 
        // HITBOX: use stable hurtbox (idle mask) and tuned reach/pads, not the sprite extents.
        var _reach = (comboCount >= 2) ? ATTACK_HITBOX_REACH_2 : ATTACK_HITBOX_REACH_1;
        var _top_pad = (comboCount >= 2) ? ATTACK_HITBOX_TOP_PAD_2 : ATTACK_HITBOX_TOP_PAD_1;
        var _bot_pad = (comboCount >= 2) ? ATTACK_HITBOX_BOT_PAD_2 : ATTACK_HITBOX_BOT_PAD_1;
        var y1 = bbox_top + _top_pad;
        var y2 = bbox_bottom - _bot_pad;
        var x1, x2;
        if (last_direction > 0) {
            x1 = bbox_right - ATTACK_HITBOX_X_INSET;
            x2 = x1 + _reach;
        } else {
            x2 = bbox_left + ATTACK_HITBOX_X_INSET;
            x1 = x2 - _reach;
        }
        // Store for debug draw (exact coords used by collision)
        debug_hitbox_x1 = x1; debug_hitbox_y1 = y1; debug_hitbox_x2 = x2; debug_hitbox_y2 = y2; debug_hitbox_active = true;
        var _hit_enemy = collision_rectangle(x1, y1, x2, y2, obj_enemy, false, true);
        var _hit_parent = noone;
        if (_hit_enemy == noone) {
            _hit_parent = collision_rectangle(x1, y1, x2, y2, obj_enemy_parent, false, true);
        }
        
        if (_hit_parent != noone) {
            attack_has_hit = true;
            with (_hit_parent) {
                scr_enemy_grounded_apply_damage(other.ATTACK_DAMAGE_PER_HIT, other.x);
                hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
            }
            global.hitstop = ATTACK_LIGHT_HITSTOP;
            hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK;
            if (comboCount >= 2) {
                hsp -= last_direction * ATTACK_COMBO2_PLAYER_RECOIL;
            }
        } else if (_hit_enemy != noone) {
            attack_has_hit = true;
            
            // PUSH ENEMY BACK - balanced for combo follow-up
            with (_hit_enemy) {
                hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
                obj_enemy_health -= other.ATTACK_DAMAGE_PER_HIT;
                
                pressure_hit_count += 1;
                pressure_window_timer = enemy_pressure_window_frames;
                
                var _armor_windup = (state == STATE_ATTACK && attack_phase == 0 && attack_phase_timer > 0
                    && attack_phase_timer <= enemy_attack_windup_armor_last_frames);
                var _armor_dash = (state == STATE_ATTACK && attack_phase == 1
                    && attack_phase_timer > (enemy_attack_dash_frames - enemy_attack_dash_super_armor_frames));
                
                if (_armor_windup || _armor_dash) {
                    if (state == STATE_ATTACK && attack_phase == 0) {
                        telegraph_shake_x = 0;
                        telegraph_shake_y = 0;
                    }
                    global.hitstop = other.ATTACK_LIGHT_HITSTOP;
                } else {
                    // Include STATE_ATTACK: punishing their swing must clear was_in_attack_threat_zone or
                    // CHASE/AGGRESSIVE never re-enters threat while you stand still in the band (looks "stuck").
                    var _interrupt = (state == STATE_ATTACK || state == STATE_PATIENT_WAIT || state == STATE_DEFENSIVE_RETREAT
                        || state == STATE_THREAT_REACTION || state == STATE_THREAT_NEUTRAL);
                    if (_interrupt) {
                        decision_cooldown_timer = max(decision_cooldown_timer, enemy_interrupt_decision_cooldown_frames);
                        threat_next_roll_retreat_bias = true;
                        threat_commit_count = 0;
                        was_in_attack_threat_zone = false;
                    }
                    
                    if (state == STATE_ATTACK) {
                        attack_hit_dealt = true;
                    }
                    image_blend = c_white;
                    telegraph_shake_x = 0;
                    telegraph_shake_y = 0;
                    
                    hit_pressure_hits = min(hit_pressure_hits + 1, 24);
                    hit_pressure_timer = other.ENEMY_HIT_PRESSURE_WINDOW_FRAMES;
                    var _mult = min(1 + max(0, hit_pressure_hits - 1) * other.HIT_PRESSURE_KB_PER_STACK,
                        other.HIT_PRESSURE_KB_MULT_CAP);
                    
                    state = STATE_STUNNED;
                    stunTimer = (other.comboCount >= 2) ? other.ENEMY_STUN_AFTER_HIT2 : other.ENEMY_STUN_AFTER_HIT1;
                    last_hit_was_finisher = (other.comboCount >= 2);
                    
                    var _pcx = (other.bbox_left + other.bbox_right) * 0.5;
                    var _ecx = (bbox_left + bbox_right) * 0.5;
                    var _knockback_dir = sign(_ecx - _pcx);
                    if (_knockback_dir == 0) _knockback_dir = other.last_direction;
                    
                    var _kx = _knockback_dir * other.ATTACK_LIGHT_KNOCKBACK * _mult;
                    knockback_pending_x = _kx;
                    knockback_pending_y = 0;
                    knockback_pending_lift = false;
                    knockbackX = _kx;
                    global.hitstop = other.ATTACK_LIGHT_HITSTOP;
                }
            }
            
            hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK;
            if (comboCount >= 2) {
                hsp -= last_direction * ATTACK_COMBO2_PLAYER_RECOIL;
            }
        }
    }
    if (!_is_swinging) debug_hitbox_active = false;
    
    // --- COMBO TRANSITION (1→2): attack_chain_latched from any X press during swing 1 ---
    if (image_index >= image_number - 1) {
        if (attack_chain_latched && comboCount < 2 && comboTimer > 0) {
            attacking = false;
            attack_lockout = 0;
            attack_buffer_timer = 0;
            attack_chain_buffer_timer = 0;
            attack_chain_latched = false;
            scr_player_attack();
            _attack_step_shift();
        } else {
            // Swing over without 1→2 chain (incl. atk2 finisher) — reset so buffer can't spawn atk3/extra atk1.
            attacking = false;
            attack_lockout = 0;
            image_blend = c_white;
            attack_recovery_grace = ATTACK_RECOVERY_GRACE;
            attack_buffer_timer = 0;
            attack_chain_buffer_timer = 0;
            attack_chain_latched = false;
            comboCount = 0;
            comboTimer = 0;
            post_attack_accel_timer = POST_ATTACK_ACCEL_FRAMES;
        }
    }
}

// Hit / interrupt can leave attacking=false while debug_hitbox_active was true — clear it here.
if (!attacking) {
    debug_hitbox_active = false;
}

// 4. DECREMENT TIMERS
if (comboTimer > 0) {
    comboTimer--;
    if (comboTimer <= 0) {
        comboCount = 0;
        attack_chain_buffer_timer = 0;
        attack_chain_latched = false;
    }
}
if (attackCooldownTimer > 0) {
    attackCooldownTimer--;
}
if (attack_recovery_grace > 0) attack_recovery_grace--;

// 5. VISUALS & CLEANUP
scr_player_invincibility();
_player_sprint_deform();

// NOTE:
// Keep sub-pixel positions for smoother movement. Draw events already snap to pixels where needed.