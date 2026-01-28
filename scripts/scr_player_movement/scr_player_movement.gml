/// @function scr_player_movement
function scr_player_movement() {
    
    // --- 0. INITIALIZATION ---
    if (is_dying) { vsp += grv; y += vsp; return; }
    
    // Collision sampling is derived from the current collision mask (bbox_*).
    // This makes the controller work for a 64x64 player today and a 96x96 mask later,
    // as long as the sprites/masks remain bottom-centered.
    var feet_y    = floor(bbox_bottom);
    var head_y    = floor(bbox_top);
    var center_y  = floor((bbox_top + bbox_bottom) * 0.5);
    var p_left    = floor(bbox_left) + 1;
    var p_right   = floor(bbox_right) - 1;
    var p_center  = floor((bbox_left + bbox_right) * 0.5);

    // --- 1. INPUT ---
    if (stunTimer <= 0) {
        key_left      = keyboard_check(vk_left);
        key_right     = keyboard_check(vk_right);
        key_jump      = keyboard_check_pressed(vk_up);
        key_jump_held = keyboard_check(vk_up); 
        key_down      = keyboard_check(vk_down);
        key_dash      = keyboard_check_pressed(ord("Z")); 
        key_attack    = keyboard_check_pressed(ord("X"));

        // Jump buffer
        if (key_jump) jump_buffer_timer = jump_buffer_max; 
        if (jump_buffer_timer > 0) jump_buffer_timer--;
        
        // Attack buffer
        if (key_attack) attack_buffer_timer = attack_buffer_max;
        if (attack_buffer_timer > 0) attack_buffer_timer--;
    }

    // --- 2. GROUNDED & COYOTE LOGIC ---
    var touch_floor = check_tile_collision(p_left,   feet_y + GROUND_CHECK_DIST) ||
                      check_tile_collision(p_center, feet_y + GROUND_CHECK_DIST) ||
                      check_tile_collision(p_right,  feet_y + GROUND_CHECK_DIST);
    
    if (touch_floor) {
        grounded = true; 
        coyote_time_timer = coyote_time_max; 
        jump_count = 0;
    } else {
        if (coyote_time_timer > 0) coyote_time_timer--;
        else grounded = false;
    }

    // --- 3. JUMP TRIGGER ---
    var jumped_this_frame = false;
    if (jump_buffer_timer > 0 && (coyote_time_timer > 0 || jump_count < 2) && !attacking) {
        vsp = -jumpsp; 
        jump_count++; 
        coyote_time_timer = 0; 
        jump_buffer_timer = 0; 
        grounded = false;
        jumped_this_frame = true;
        
        if (is_dashing || abs(hsp) > walksp) {
            runMomentum = hsp; 
            is_dashing = false; 
        }
    }

    // --- 4. GRAVITY & DASH LOGIC ---
    vsp += grv; 
    if (vsp < 0 && !key_jump_held) vsp = max(vsp, -jumpsp / 3); 
    
    if (stunTimer > 0) {
        stunTimer--;
        hsp = knockBackX; vsp = knockBackY;
        knockBackX *= 0.9; knockBackY += grv; 
    } else {
        if (dash_cooldown > 0) dash_cooldown--;
        
        // Dash check (excluding landing animation since it's handled separately)
        if (key_dash && dash_cooldown <= 0 && grounded && !attacking && sprite_index != spr_mc_jump) {
            is_dashing = true; 
            dash_timer = dash_duration; 
            dash_cooldown = dash_duration + 8;
            hsp = (key_right - key_left == 0 ? last_direction : (key_right - key_left)) * dash_speed;
            runMomentum = hsp;
            coyote_time_timer = coyote_time_max;
        }
        
        if (is_dashing) {
            dash_timer--;
            image_speed = 0; // Freeze on first dash frame for clarity
            if (image_index > 1.9) image_index = 0; // Keep early dash frames
            if (dash_timer % 4 == 0) instance_create_layer(x, y, "Instances", obj_afterimage);
            if (dash_timer <= 0) {
                is_dashing = false;
                image_speed = 1; // Resume animation
            }
        } else if (!attacking) {
            var inputDir = (key_right - key_left);
            
            if (grounded && !jumped_this_frame) { 
                hsp = walksp * inputDir;
                runMomentum = 0; 
            } else { 
                if (abs(runMomentum) > walksp) {
                    // Frame-rate independent decay using lerp
                    runMomentum = lerp(runMomentum, 0, MOMENTUM_DECAY_NORMAL); 
                    if (inputDir != 0 && sign(inputDir) != sign(runMomentum)) {
                        runMomentum = lerp(runMomentum, 0, MOMENTUM_DECAY_TURNING); 
                    }
                    hsp = runMomentum;
                    if (abs(runMomentum) <= walksp + MOMENTUM_CUTOFF) runMomentum = 0;
                } else {
                    hsp = walksp * inputDir;
                }
            }
        }
    }

    // --- 5. COLLISIONS (Horizontal) ---
    if (hsp != 0) {
        var _h_step = sign(hsp);
        var _target_side = (hsp > 0) ? floor(bbox_right) : floor(bbox_left);
    
        // Always do pixel-stepped movement for robustness (prevents tunneling if speeds increase later).
        repeat(abs(ceil(hsp))) {
            // Re-sample bounds each step (sprite/mask can change; x/y can change)
            feet_y    = floor(bbox_bottom);
            head_y    = floor(bbox_top);
            center_y  = floor((bbox_top + bbox_bottom) * 0.5);
            p_left    = floor(bbox_left) + 1;
            p_right   = floor(bbox_right) - 1;
            p_center  = floor((bbox_left + bbox_right) * 0.5);

            _target_side = (hsp > 0) ? floor(bbox_right) : floor(bbox_left);

            // Primary horizontal clearance check (sample at head/center/toe).
            var _clear = !check_tile_collision(_target_side + _h_step, head_y + WALL_CHECK_OFFSET) &&
                         !check_tile_collision(_target_side + _h_step, center_y) &&
                         !check_tile_collision(_target_side + _h_step, feet_y - 2);

            if (_clear) {
                x += _h_step;
            } else {
                // --- Ledge/CORNER correction (tiny step-up forgiveness) ---
                // If we're grounded and blocked by a 1-2px lip, try nudging up.
                var _stepped = false;
                if (grounded && vsp >= 0 && !attacking) {
                    for (var _step_up = 1; _step_up <= 2; _step_up++) {
                        var _feet_y_u   = feet_y   - _step_up;
                        var _head_y_u   = head_y   - _step_up;
                        var _center_y_u = center_y - _step_up;

                        // Ensure we won't clip into a ceiling when stepping up (simple head clearance).
                        var _ceiling_clear = !check_tile_collision(p_left,   _head_y_u) &&
                                             !check_tile_collision(p_center, _head_y_u) &&
                                             !check_tile_collision(p_right,  _head_y_u);

                        if (_ceiling_clear &&
                            !check_tile_collision(_target_side + _h_step, _head_y_u + WALL_CHECK_OFFSET) &&
                            !check_tile_collision(_target_side + _h_step, _center_y_u) &&
                            !check_tile_collision(_target_side + _h_step, _feet_y_u - 2)) {
                            y -= _step_up;
                            x += _h_step;
                            _stepped = true;
                            break;
                        }
                    }
                }

                if (!_stepped) {
                    hsp = 0;
                    runMomentum = 0;
                    break;
                }
            }
        }
    }

    // --- 6. COLLISIONS (Vertical) ---
    // Re-sample bounds after horizontal movement
    feet_y    = floor(bbox_bottom);
    head_y    = floor(bbox_top);
    center_y  = floor((bbox_top + bbox_bottom) * 0.5);
    p_left    = floor(bbox_left) + 1;
    p_right   = floor(bbox_right) - 1;
    p_center  = floor((bbox_left + bbox_right) * 0.5);

    if (vsp != 0) {
        // Pixel-step vertical movement for consistent collision with tilemap pixels.
        var _v_step = sign(vsp);
        repeat(abs(ceil(vsp))) {
            var _check_y = (_v_step < 0) ? head_y : feet_y;
            if (!check_tile_collision(p_left,   _check_y + _v_step) &&
                !check_tile_collision(p_center, _check_y + _v_step) &&
                !check_tile_collision(p_right,  _check_y + _v_step)) {
                y += _v_step;
                // update sampled y bounds as we move
                feet_y   = floor(bbox_bottom);
                head_y   = floor(bbox_top);
                center_y = floor((bbox_top + bbox_bottom) * 0.5);
            } else {
                // Snap to integer pixel on contact
                y = (_v_step > 0) ? floor(y) : ceil(y);
                vsp = 0;
                break;
            }
        }
    }

    // --- 7. ANIMATION (reverted, cleaned up) ---
    var _input_dir = key_right - key_left;

    if (!attacking) {
        if (grounded) {
            if (sprite_index == spr_mc_jump) {
                // Frame 8-10 are the landing crouch (11 frames total: 0-10)
                if (image_index < 8) image_index = 8;
                
                // Allow dash to cancel landing crouch cleanly
                if (key_dash && dash_cooldown <= 0) {
                    is_dashing = true;
                    dash_timer = dash_duration;
                    dash_cooldown = dash_duration + 8;
                    hsp = (key_right - key_left == 0 ? last_direction : (key_right - key_left)) * dash_speed;
                    runMomentum = hsp;
                    sprite_index = spr_mc_dash;
                    image_index = 0;
                } else if (_input_dir != 0) {
                    // Skip crouch if moving
                    sprite_index = (is_dashing) ? spr_mc_dash : spr_mc_jog;
                    image_index = 0;
                } else if (image_index >= 10.5) { 
                    sprite_index = spr_mc_idle;
                    image_index = 0;
                }
            } else if (is_dashing || sprite_index == spr_mc_dash) {
                if (sprite_index != spr_mc_dash) { sprite_index = spr_mc_dash; image_index = 0; }
            
                if (is_dashing) {
                    image_speed = 1;
                    if (image_index >= 5.9) image_index = 0; // Loop frames 0-5
                } else {
                    // Dash ended: either continue running or play brief reel-back
                    if (_input_dir != 0) { 
                        sprite_index = spr_mc_jog; 
                        image_index = 0; 
                    } else {
                        // Reel back (Frames 6-8) at half speed
                        image_speed = 0.5;
                        if (image_index < 6) image_index = 6; // Start at frame 6
                        if (image_index >= 8.8) { // After frame 8 completes
                            sprite_index = spr_mc_idle; 
                            image_index = 0; 
                        }
                    }
                }
            } else {
                // Normal ground movement
                image_speed = 1;
                sprite_index = (abs(hsp) > MOVEMENT_THRESHOLD) ? spr_mc_jog : spr_mc_idle;
            }
        } else {
            // Air Logic
            sprite_index = spr_mc_jump;
            
            if (vsp < JUMP_RISE_THRESHOLD) {
                // Rising
                image_speed = 1;
                image_index = 0;
            } else if (vsp >= JUMP_PEAK_MIN && vsp <= JUMP_PEAK_MAX) {
                // Peak (apex of jump)
                image_speed = 1;
                image_index = 2;
            } else {
                // Falling (vsp > 1)
                
                // Landing detection: check both proximity and velocity
                var _is_near_ground = check_tile_collision(floor(x), y + LANDING_ANIM_DIST);
                
                if (_is_near_ground && vsp > 0) {
                    // Very close to ground AND falling = landing imminent
                    image_speed = 1;
                    image_index = 8;
                } else {
                    // Normal falling: hair flicker (frames 5 and 6)
                    image_speed = 0; // Stop automatic animation
                    
                    // Increment counter and flicker every 5 frames
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= 5) {
                        hair_flicker_counter = 0;
                    }
                    
                    // Alternate between 5 and 6
                    image_index = (hair_flicker_counter < 2.5) ? 5 : 6;
                }
            }
        }
    } else {
        // Keep attack swing animation at designed speed
        image_speed = 1; 
    }

    // --- 8. DIRECTION FLIPPING (with attack lock) ---
    if (_input_dir != 0 && stunTimer <= 0 && !attacking) {
        image_xscale = (_input_dir > 0) ? image_base_scale : -image_base_scale;
        last_direction = _input_dir;
    }
}