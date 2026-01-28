// --- obj_enemy STEP EVENT ---

// Apply pending knockback after hitstop ends
if (global.hitstop == 0 && (knockback_pending_x != 0 || knockback_pending_y != 0)) {
    // ALWAYS apply horizontal knockback
    knockbackX = knockback_pending_x;
    
    // Apply vertical knockback and lift
    if (knockback_pending_lift) {
        y -= 4; // Lift higher off ground
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
        state = STATE_IDLE;
        knockbackX = 0;
        hsp = 0;
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