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
if (attack_buffer_timer > 0 && attackCooldownTimer <= 0 && grounded) {
    scr_player_attack(); 
    attack_buffer_timer = 0; // Consume the buffer
    
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
    
    // --- COMBO TRANSITION ---
    if (image_index >= image_number - 1) {
        if (combo_buffer) {
            attacking = false;
            scr_player_attack(); 
        } else {
            attacking = false;
            image_blend = c_white;
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

// 5. VISUALS & CLEANUP
scr_player_invincibility();

// NOTE:
// Keep sub-pixel positions for smoother movement. Draw events already snap to pixels where needed.