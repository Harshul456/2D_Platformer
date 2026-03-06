// --- IN obj_player STEP EVENT ---

// --- HITSTOP CHECK (at the very start of Step Event) ---
if (scr_hitstop_handler()) {
    exit; // Skip all movement/logic during hitstop
}

// Toggle reflections while recording (F2)
if (keyboard_check_pressed(vk_f2)) {
    global.reflections_enabled = !global.reflections_enabled;
}

// 1. PROCESS NORMAL MOVEMENT 
scr_player_movement();

// 2. PROCESS ATTACK INPUT (with buffer)
// Skip if attacking — let combo transition handle chaining.
// Skip if attack_lockout > 0: prevents starting before current attack finishes.
// Skip if attack_recovery_grace > 0: prevents restarting attack 1 immediately after it ends (8-frame cooldown)
if (!attacking && attack_lockout <= 0 && attack_recovery_grace <= 0 && attack_buffer_timer > 0 && attackCooldownTimer <= 0 && grounded) {
    scr_player_attack(); 
    attack_buffer_timer = 0; // Consume the buffer — one press = one attack
    
    // Only reset these if the script actually started a NEW swing
    if (image_index == 0) {
        attackCooldownTimer = attackCooldown;
        attack_has_hit = false; 
        is_dashing = false; 
        dash_timer = 0;
    }
}

// 3. PROCESS THE ATTACK STATE & PHYSICS
if (attacking) {
    if (attack_lockout > 0) attack_lockout--;
    // --- STRONGER LUNGE FRICTION ---
    hsp = lerp(hsp, 0, ATTACK_LUNGE_FRICTION);
    if (abs(hsp) < ATTACK_LUNGE_CUTOFF) hsp = 0;
    
    // --- STOP ON HIT ---
    if (attack_has_hit) hsp *= ATTACK_ON_HIT_HSLOW;
    
    // --- HIT DETECTION ---
    var _is_swinging = (image_index >= 1 && image_index <= 3);
    
    if (_is_swinging && !attack_has_hit) { 
        var _w = (bbox_right - bbox_left);
        var _reach = max(ATTACK_REACH_MIN, _w * ATTACK_REACH_FACTOR);
        var _pad_y = ATTACK_HITBOX_PAD_Y;

        var y1 = bbox_top + _pad_y;
        var y2 = bbox_bottom - _pad_y;
        var x1, x2;
        if (last_direction > 0) {
            x1 = bbox_right;
            x2 = bbox_right + _reach;
        } else {
            x1 = bbox_left - _reach;
            x2 = bbox_left;
        }
        // Store for debug draw (exact coords used by collision)
        debug_hitbox_x1 = x1; debug_hitbox_y1 = y1; debug_hitbox_x2 = x2; debug_hitbox_y2 = y2; debug_hitbox_active = true;
        var _hit_enemy = collision_rectangle(x1, y1, x2, y2, obj_enemy, false, true);
        
        if (_hit_enemy != noone) {
            attack_has_hit = true;
            
            // PUSH ENEMY BACK - balanced for combo follow-up
            with (_hit_enemy) {
                hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
                obj_enemy_health -= other.ATTACK_DAMAGE_PER_HIT;
                
                if (state != STATE_STUNNED) {
                    state = STATE_STUNNED;
                    stunTimer = other.ATTACK_STUN_FRAMES;
                }
                
                var _knockback_dir = -sign(other.x - x);
                if (_knockback_dir == 0) _knockback_dir = other.last_direction;
                
                if (other.comboCount < 3) {
                    knockback_pending_x = _knockback_dir * other.ATTACK_LIGHT_KNOCKBACK;
                    knockback_pending_y = 0;
                    knockback_pending_lift = false;
                    global.hitstop = other.ATTACK_LIGHT_HITSTOP;
                } else {
                    knockback_pending_x = _knockback_dir * other.ATTACK_FINISHER_KNOCKBACK_X;
                    knockback_pending_y = other.ATTACK_FINISHER_KNOCKBACK_Y;
                    knockback_pending_lift = true;
                    global.hitstop = other.ATTACK_FINISHER_HITSTOP;
                }
            }
            
            hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK;
        }
    }
    if (!_is_swinging) debug_hitbox_active = false;
    
    // --- RELEASE-THEN-PRESS: 1→2 only — detects quick double-tap (key briefly released then pressed)
    if (comboCount == 1 && keyboard_check_released(ord("X"))) attack_key_released_this_swing = true;
    
    // --- COMBO BUFFER: new press (buffer) OR release-then-press for 1→2 (single hold = no chain) ---
    var _has_input = (attack_buffer_timer > 0);
    if (comboCount == 1) _has_input = _has_input || (attack_key_released_this_swing && keyboard_check(ord("X")));
    if (image_index > image_number * 0.22 && _has_input) {
        combo_buffer = true;
    }
    
    // --- COMBO TRANSITION ---
    if (image_index >= image_number - 1) {
        if (combo_buffer && comboCount < 3 && comboTimer > 0) {
            // Only chain 1→2 and 2→3; finisher (3) ends the combo. comboTimer>0 prevents chain when combo expired.
            attacking = false;
            attack_lockout = 0;
            attack_buffer_timer = 0;  // Consume buffer so each chain requires a new press
            scr_player_attack(); 
        } else {
            attacking = false;
            attack_lockout = 0;
            image_blend = c_white;
            attack_recovery_grace = ATTACK_RECOVERY_GRACE;  // Brief protection so direction+mash doesn't get hit
            attack_buffer_timer = 0;  // Consume so leftover buffer doesn't immediately start attack 1 again
        }
    }
}

// 4. DECREMENT TIMERS
if (comboTimer > 0) {
    comboTimer--;
    if (comboTimer <= 0) comboCount = 0;
}
if (attackCooldownTimer > 0) {
    attackCooldownTimer--;
}
if (attack_recovery_grace > 0) attack_recovery_grace--;

// 5. VISUALS & CLEANUP
scr_player_invincibility();

// NOTE:
// Keep sub-pixel positions for smoother movement. Draw events already snap to pixels where needed.