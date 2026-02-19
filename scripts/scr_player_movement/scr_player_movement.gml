/// @function scr_player_movement
/// @description Main player movement: input, grounded/coyote, wall cling, jump, gravity/dash,
///             horizontal/vertical collision, 6c grounded re-check, animation, direction.
///             All tunable numbers live in obj_player Create (no magic numbers here).
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
    // We only set grounded when center is on floor (and not clinging). That way wall tiles under
    // left/right don't count as "ground" and we avoid idle/wall flicker when sliding down a wall.
    var touch_floor_center = check_tile_collision(p_center, feet_y + GROUND_CHECK_DIST);
    var touch_floor_any = touch_floor_center ||
                          check_tile_collision(p_left,   feet_y + GROUND_CHECK_DIST) ||
                          check_tile_collision(p_right,  feet_y + GROUND_CHECK_DIST);
    
    // Only count as grounded when center is on floor AND we're not clinging (so wall-ledge doesn't flicker to idle)
    if (touch_floor_center && wall_side == 0) {
        grounded = true; 
        coyote_time_timer = coyote_time_max; 
        jump_count = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;  // Reset so next air time can cling/jump from any wall
    } else {
        if (touch_floor_any) coyote_time_timer = coyote_time_max; // Coyote from narrow platform
        if (coyote_time_timer > 0) coyote_time_timer--;
        else grounded = false;
    }

    // --- 2b. WALL CLING DETECTION — only when in air and feet not on ground (no cling over ledges) ---
    if (wall_jump_lock > 0) wall_jump_lock--;
    if (wall_jump_extend_timer > 0) wall_jump_extend_timer--;
    // During wall_jump_lock we can still cling to the *opposite* wall (for side-to-side wall jump)
    if (!grounded && !attacking) {
        // If feet are on solid ground (center over a tile), don't cling — land instead
        if (touch_floor_center) {
            wall_side = 0;
            wall_cling_grace = 0;
            wall_cling_frames = 0;
        } else {
            var _wall_L1 = floor(bbox_left) - 1;
            var _wall_L2 = floor(bbox_left) - 2;
            var _wall_R1 = floor(bbox_right) + 1;
            var _wall_R2 = floor(bbox_right) + 2;
            // Wall must be at HEAD level (hands can reach) — no cling when only feet are at wall top
            var _wall_at_head_left  = check_tile_collision(_wall_L1, head_y) || check_tile_collision(_wall_L2, head_y);
            var _wall_at_head_right = check_tile_collision(_wall_R1, head_y) || check_tile_collision(_wall_R2, head_y);
            var _wall_at_body_left  = check_tile_collision(_wall_L1, center_y) || check_tile_collision(_wall_L1, feet_y) ||
                                      check_tile_collision(_wall_L2, center_y) || check_tile_collision(_wall_L2, feet_y);
            var _wall_at_body_right = check_tile_collision(_wall_R1, center_y) || check_tile_collision(_wall_R1, feet_y) ||
                                      check_tile_collision(_wall_R2, center_y) || check_tile_collision(_wall_R2, feet_y);
            var _wall_left  = _wall_at_head_left && _wall_at_body_left;
            var _wall_right = _wall_at_head_right && _wall_at_body_right;
            // Only cling at apex or when falling — rising keeps full jump animation
            // During lock: only allow cling to the *opposite* wall (so we can side-to-side wall jump)
            var _can_cling = (vsp >= wall_cling_vsp_min);
            var _can_cling_left  = _can_cling && _wall_left && key_left && (wall_jump_lock <= 0 || wall_jump_last_side != -1);
            var _can_cling_right = _can_cling && _wall_right && key_right && (wall_jump_lock <= 0 || wall_jump_last_side != 1);
            if (_can_cling_left) {
                wall_side = -1;
                wall_cling_grace = wall_cling_grace_frames;
                wall_cling_frames++;
            } else if (_can_cling_right) {
                wall_side = 1;
                wall_cling_grace = wall_cling_grace_frames;
                wall_cling_frames++;
            } else if (wall_cling_grace > 0) {
                wall_cling_grace--;
            } else {
                wall_side = 0;
                wall_cling_frames = 0;
            }
        }
    } else if (grounded) {
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
    } else {
        wall_cling_frames = 0;
    }
    // Only clear grounded when clinging and not standing on floor (so landing clears cling)
    if (wall_side != 0 && !touch_floor_center) grounded = false;

    // --- 3. JUMP TRIGGER (ground, air, or wall jump) ---
    var jumped_this_frame = false;
    // Wall jump: allowed from opposite wall (side-to-side). Same wall is blocked via wall_jump_last_side.
    var _wall_jump_ok = (jump_count < 2) || (wall_side != wall_jump_last_side);
    if (wall_side != 0 && key_jump && !attacking && _wall_jump_ok) {
        wall_jump_last_side = wall_side;  // Remember which wall we jumped from (block re-stick to same wall)
        vsp = -jumpsp;
        hsp = -wall_side * wall_jump_hsp;
        last_direction = -wall_side;   // Face away from wall (Mario/Sonic style)
        jump_count++;
        jump_buffer_timer = 0;
        wall_jump_lock = wall_jump_lock_frames;
        wall_jump_extend_timer = wall_jump_extend_time; // Show "extend" frame
        wall_side = 0;
        wall_cling_frames = 0;
        jumped_this_frame = true;
        runMomentum = hsp;
    } else if (jump_buffer_timer > 0 && (coyote_time_timer > 0 || jump_count < 2) && !attacking) {
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
    if (wall_side != 0) {
        vsp += grv;
        vsp = min(vsp, wall_slide_speed); // Slow slide down the wall
    } else {
        vsp += grv;
        // Short-hop: release jump early caps rise speed (jump_cut_multiplier)
        if (vsp < 0 && !key_jump_held) vsp = max(vsp, jumpsp * (-jump_cut_multiplier));
    }
    
    if (stunTimer > 0) {
        stunTimer--;
        hsp = knockBackX; vsp = knockBackY;
        knockBackX *= knockback_friction; knockBackY += grv; 
    } else {
        if (dash_cooldown > 0) dash_cooldown--;
        
        // Dash check (excluding landing animation since it's handled separately)
        if (key_dash && dash_cooldown <= 0 && grounded && !attacking && sprite_index != spr_mc_jump) {
            is_dashing = true;
            dash_timer = dash_duration;
            dash_cooldown = dash_duration + dash_cooldown_extra;
            hsp = (key_right - key_left == 0 ? last_direction : (key_right - key_left)) * dash_speed;
            runMomentum = hsp;
            coyote_time_timer = coyote_time_max;
        }
        
        if (is_dashing) {
            dash_timer--;
            image_speed = 0;
            if (image_index > 1.9) image_index = 0; // Loop early dash frames
            if (dash_timer % dash_afterimage_interval == 0) instance_create_layer(x, y, "Instances", obj_afterimage);
            if (dash_timer <= 0) {
                is_dashing = false;
                image_speed = 1; // Resume animation
            }
        } else if (!attacking) {
            var inputDir = (key_right - key_left);
            if (wall_side != 0) {
                hsp = 0; // Stay stuck to wall
            } else if (grounded && !jumped_this_frame) { 
                hsp = walksp * inputDir;
                runMomentum = 0; 
            } else if (wall_jump_lock > 0) {
                // Mario-style: always jump off away from wall; ignore held direction for lock duration
                hsp = runMomentum;
                runMomentum = lerp(runMomentum, 0, MOMENTUM_DECAY_NORMAL);
                if (abs(runMomentum) <= walksp + MOMENTUM_CUTOFF) runMomentum = 0;
            } else { 
                if (abs(runMomentum) > walksp) {
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
                         !check_tile_collision(_target_side + _h_step, feet_y - LEDGE_TOE_INSET);

            if (_clear) {
                x += _h_step;
            } else {
                // --- Ledge/corner correction: step up 1–LEDGE_STEP_MAX px if blocked by small lip ---
                var _stepped = false;
                if (grounded && vsp >= 0 && !attacking) {
                    for (var _step_up = 1; _step_up <= LEDGE_STEP_MAX; _step_up++) {
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
                            !check_tile_collision(_target_side + _h_step, _feet_y_u - LEDGE_TOE_INSET)) {
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

    // --- 5b. RESOLVE WALL CLING OVERLAP ---
    // If we're clinging and overlapping the wall (e.g. after horizontal move), nudge out 1px.
    if (wall_side != 0) {
        var _wy = floor((bbox_top + bbox_bottom) * 0.5);
        if (wall_side == -1 && check_tile_collision(floor(bbox_left), _wy)) x += 1;   // Left wall: push right
        if (wall_side == 1  && check_tile_collision(floor(bbox_right), _wy)) x -= 1;   // Right wall: push left
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

    // --- 6b. RESOLVE OVERLAP WITH PIT/HAZARD (prevent clipping inside tile/pit) ---
    var _hazard = instance_place(x, y, obj_hazard_parent);
    if (_hazard != noone && !is_dying) {
        // Push out along the axis with smallest overlap (pop out nearest edge)
        var _dx_left   = _hazard.bbox_left   - bbox_right;   // negative = move left
        var _dx_right  = _hazard.bbox_right  - bbox_left;    // positive = move right
        var _dy_up     = _hazard.bbox_top    - bbox_bottom; // negative = move up
        var _dy_down   = _hazard.bbox_bottom - bbox_top;    // positive = move down
        var _best_dx = 0;
        var _best_dy = 0;
        var _min = 99999;
        if (abs(_dx_left) < _min && _dx_left != 0) { _min = abs(_dx_left); _best_dx = _dx_left; _best_dy = 0; }
        if (abs(_dx_right) < _min && _dx_right != 0) { _min = abs(_dx_right); _best_dx = _dx_right; _best_dy = 0; }
        if (abs(_dy_up) < _min && _dy_up != 0) { _min = abs(_dy_up); _best_dx = 0; _best_dy = _dy_up; }
        if (abs(_dy_down) < _min && _dy_down != 0) { _min = abs(_dy_down); _best_dx = 0; _best_dy = _dy_down; }
        x += _best_dx;
        y += _best_dy;
    }

    // --- 6c. RE-CHECK GROUNDED AFTER VERTICAL MOVEMENT ---
    // Grounded is first set at step start (before vertical move). Re-check here so on the frame we
    // land we're already grounded for animation (no one frame of fall sprite on ground). Use
    // left/center/right so landing on the edge of a tile (e.g. after wall jump) still counts.
    var _feet_y_now = floor(bbox_bottom);
    var _p_left_now   = floor(bbox_left) + 1;
    var _p_right_now  = floor(bbox_right) - 1;
    var _p_center_now = floor((bbox_left + bbox_right) * 0.5);
    var _on_ground_now = check_tile_collision(_p_center_now, _feet_y_now + GROUND_CHECK_DIST) ||
                         check_tile_collision(_p_left_now,   _feet_y_now + GROUND_CHECK_DIST) ||
                         check_tile_collision(_p_right_now,  _feet_y_now + GROUND_CHECK_DIST);
    if (_on_ground_now) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;
    }

    // --- 7. ANIMATION (reverted, cleaned up) ---
    var _input_dir = key_right - key_left;

    if (!attacking) {
        if (grounded) {
            if (sprite_index == spr_mc_jump) {
                // Landing crouch: jump sprite frames ANIM_LAND_CROUCH_START..ANIM_LAND_CROUCH_END
                if (image_index < ANIM_LAND_CROUCH_START) image_index = ANIM_LAND_CROUCH_START;
                image_speed = 1; // Fall anim uses image_speed = 0; restore so crouch can play
                
                if (key_dash && dash_cooldown <= 0) {
                    is_dashing = true;
                    dash_timer = dash_duration;
                    dash_cooldown = dash_duration + dash_cooldown_extra;
                    hsp = (key_right - key_left == 0 ? last_direction : (key_right - key_left)) * dash_speed;
                    runMomentum = hsp;
                    sprite_index = spr_mc_dash;
                    image_index = 0;
                    force_landing_crouch = false;
                } else if (_input_dir != 0 && !force_landing_crouch) {
                    // Skip crouch if moving (unless we just landed from wall — play crouch first)
                    sprite_index = (is_dashing) ? spr_mc_dash : spr_mc_jog;
                    image_index = 0;
                } else if (image_index >= ANIM_LAND_CROUCH_END) {
                    sprite_index = spr_mc_idle;
                    image_index = 0;
                    force_landing_crouch = false;
                }
            } else if (sprite_index == spr_mc_walljump) {
                // Landed from wall: play full landing crouch (don't snap to idle/jog while holding direction)
                image_speed = 1;
                sprite_index = spr_mc_jump;
                image_index = ANIM_LAND_CROUCH_START;
                force_landing_crouch = true;
            } else if (is_dashing || sprite_index == spr_mc_dash) {
                if (sprite_index != spr_mc_dash) { sprite_index = spr_mc_dash; image_index = 0; }
            
                if (is_dashing) {
                    image_speed = 1;
                    if (image_index >= ANIM_DASH_LOOP_END) image_index = 0;
                } else {
                    if (_input_dir != 0) {
                        sprite_index = spr_mc_jog;
                        image_index = 0;
                    } else {
                        image_speed = 0.5;
                        if (image_index < ANIM_DASH_REEL_START) image_index = ANIM_DASH_REEL_START;
                        if (image_index >= ANIM_DASH_REEL_END) {
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
            // Air Logic — wall cling/extend take priority so jump sprite never overrides
            var _on_wall = (wall_side != 0);
            var _in_wall_extend = (wall_jump_extend_timer > 0);
            if (_on_wall) {
                sprite_index = spr_mc_walljump;
                image_index = 0;   // Cling (frame 0). If your sprite has cling on frame 1, use 1 here.
                image_speed = 0;
                image_xscale = -wall_side * image_base_scale; // Face away from wall (section 8 re-applies to be sure)
            } else if (_in_wall_extend) {
                sprite_index = spr_mc_walljump;
                image_index = 1;   // Extend / push-off (frame 1). If your sprite has extend on frame 0, use 0 here.
                image_speed = 0;
                image_xscale = last_direction * image_base_scale;
            }
            if (!_on_wall && !_in_wall_extend) {
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
                    image_speed = 1;
                    image_index = ANIM_LAND_CROUCH_START; // Landing imminent: show crouch early
                } else {
                    image_speed = 0;
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= ANIM_HAIR_FLICKER_INTERVAL) hair_flicker_counter = 0;
                    image_index = (hair_flicker_counter < ANIM_HAIR_FLICKER_THRESHOLD) ? 5 : 6;
                }
            }
            }  // end if (!_on_wall && !_in_wall_extend) — jump sprite only when not wall state
        }
    } else {
        // Keep attack swing animation at designed speed
        image_speed = 1; 
    }

    // --- 8. DIRECTION FLIPPING (with attack lock; don't override wall cling facing) ---
    if (wall_jump_lock > 0) {
        // During lock: face the direction we're moving (away from wall), ignore held input
        var _move_dir = sign(hsp);
        if (_move_dir != 0) {
            image_xscale = (_move_dir > 0) ? image_base_scale : -image_base_scale;
            last_direction = _move_dir;
        }
    } else if (wall_side != 0) {
        // Cling: face AWAY from wall (so back to camera, hands on wall — -wall_side flips correctly)
        image_xscale = -wall_side * image_base_scale;
        last_direction = wall_side;
    } else if (_input_dir != 0 && stunTimer <= 0 && !attacking) {
        image_xscale = (_input_dir > 0) ? image_base_scale : -image_base_scale;
        last_direction = _input_dir;
    }
}