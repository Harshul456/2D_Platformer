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
        has_hit = false; 
        is_dashing = false; 
        dash_timer = 0;
    }
}

// 3. PROCESS THE ATTACK STATE & PHYSICS
if (attacking) {
    // --- STRONGER LUNGE FRICTION ---
    // Apply much stronger friction to stop sliding into enemies
    hsp = lerp(hsp, 0, 0.35);
    if (abs(hsp) < 0.3) hsp = 0;
    
    // --- STOP ON HIT ---
    // When you hit an enemy, immediately reduce momentum to prevent sliding through
    if (has_hit) {
        hsp *= 0.5;
    }
    
    // --- HIT DETECTION ---
    var _is_swinging = (image_index >= 1 && image_index <= 3);
    
    if (_is_swinging && !has_hit) { 
        // Hitbox scales with current collision mask size (64x64 now, 96x96 later)
        var _w = (bbox_right - bbox_left);
        var _reach = max(16, _w * 0.42); // ~27px reach for a 64px-wide character
        var _pad_y = 4;

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
            has_hit = true;
            
            // PUSH ENEMY BACK - balanced for combo follow-up
            with (_hit_enemy) {
                // Damage and state change happen immediately
                hit_blink_timer = 20; 
                obj_enemy_health -= 20;
                
                if (state != STATE_STUNNED) {
                    state = STATE_STUNNED;
                    stunTimer = 30;
                }
                
                // Store knockback values to apply AFTER hitstop
                if (other.comboCount < 3) {
                    knockback_pending_x = other.last_direction * 1.5;
                    knockback_pending_y = 0;
                    knockback_pending_lift = false;
                    global.hitstop = 3; // Light hit = short freeze
                } else {
                    // Finisher - big horizontal push + launch
                    knockback_pending_x = other.last_direction * 6;
                    knockback_pending_y = -6;
                    knockback_pending_lift = true;
                    global.hitstop = 8;
                }
            }
            
            // Small pushback on hit to prevent overlap
            hsp -= last_direction * 0.5;
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