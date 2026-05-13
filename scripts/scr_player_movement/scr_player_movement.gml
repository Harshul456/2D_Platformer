/// @function scr_player_movement
/// @description Main player movement: input, grounded/coyote, wall cling, jump, gravity/dash,
///             horizontal/vertical collision, 6c grounded re-check, animation, direction.
///             All tunable numbers live in obj_player Create (no magic numbers here).
function scr_player_movement() {
    
    // --- 0. INITIALIZATION ---
    if (is_dying) { vsp += grv; y += vsp; return; }
    shelf_threshold_snap_this_step = false;
    global.player_ledge_bb_prev = shelf_bb_bottom_prev;
    global.player_move_vsp = vsp;
    
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
        
        // Attack buffer: only while idle (refilling during swing); chain buffer for 1→2 on new press during swing 1
        if (key_attack) {
            if (!attacking) attack_buffer_timer = attack_buffer_max;
            else if (attacking && comboCount == 1) attack_chain_buffer_timer = attack_chain_buffer_max;
        }
        if (!attacking && attack_buffer_timer > 0) attack_buffer_timer--;
        if (attack_chain_buffer_timer > 0) attack_chain_buffer_timer--;
    }

    // --- 2. GROUNDED & COYOTE LOGIC ---
    var p_g_left  = floor(bbox_left) + GROUND_PROBE_EDGE_INSET;
    var p_g_right = floor(bbox_right) - GROUND_PROBE_EDGE_INSET;
    if (p_g_left >= p_g_right) {
        p_g_left = p_left;
        p_g_right = p_right;
    }
    var _floor_probe_y = feet_y + GROUND_CHECK_DIST;
    var _tm_lc = global.tilemap_collision_id;
    var _feet_on_cap_cell = (_tm_lc != noone) && (
        tilemap_cell_thin_floor_near_feet(_tm_lc, p_center, feet_y) ||
        tilemap_cell_thin_floor_near_feet(_tm_lc, p_left, feet_y) ||
        tilemap_cell_thin_floor_near_feet(_tm_lc, p_right, feet_y) ||
        tilemap_cell_thin_floor_near_feet(_tm_lc, p_g_left, feet_y) ||
        tilemap_cell_thin_floor_near_feet(_tm_lc, p_g_right, feet_y));
    var _ix_l0 = (_tm_lc != noone) ? tilemap_shelf_index_at_pixel(_tm_lc, p_left, _floor_probe_y) : -1;
    var _ix_c0 = (_tm_lc != noone) ? tilemap_shelf_index_at_pixel(_tm_lc, p_center, _floor_probe_y) : -1;
    var _ix_r0 = (_tm_lc != noone) ? tilemap_shelf_index_at_pixel(_tm_lc, p_right, _floor_probe_y) : -1;
    var _shelf_strict_34_36 = (_ix_l0 == 34 || _ix_l0 == 36 || _ix_c0 == 34 || _ix_c0 == 36 || _ix_r0 == 34 || _ix_r0 == 36);
    var _shelf_cap_feet_s2 = (_tm_lc != noone) && tilemap_shelf_cap_near_feet(_tm_lc, p_left, p_center, p_right, feet_y);
    var _shelf_touch_tile1 = (_ix_l0 == 1 || _ix_c0 == 1 || _ix_r0 == 1);
    var _xl_floor = _feet_on_cap_cell ? p_left : p_g_left;
    var _xr_floor = _feet_on_cap_cell ? p_right : p_g_right;
    var touch_floor_center = check_tile_collision(p_center, _floor_probe_y);
    var touch_floor_gl = check_tile_collision(_xl_floor, _floor_probe_y);
    var touch_floor_gr = check_tile_collision(_xr_floor, _floor_probe_y);
    var touch_floor_any = touch_floor_center || touch_floor_gl || touch_floor_gr;
    var _raw_support_n = (touch_floor_center ? 1 : 0) +
        (check_tile_collision(p_left,  _floor_probe_y) ? 1 : 0) +
        (check_tile_collision(p_right, _floor_probe_y) ? 1 : 0);
    var touch_floor_majority = (_raw_support_n >= GROUND_LAND_VOTES_MIN_AIR);
    var _stand_l = check_floor_standable(_xl_floor, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_c = check_floor_standable(p_center, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_r = check_floor_standable(_xr_floor, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var touch_stand_majority = ((_stand_l ? 1 : 0) + (_stand_c ? 1 : 0) + (_stand_r ? 1 : 0) >= GROUND_LAND_VOTES_MIN_AIR);
    // Strict vote logic blocks relaxed lip grounding; cap geometry already prevents standing past the art.
    var _strict3426_ground = _shelf_strict_34_36 && _shelf_cap_feet_s2 && wall_side == 0
        && touch_floor_any && (_stand_l || _stand_c || _stand_r) && abs(vsp) <= SHELF_STAND_VSP_ABS_MAX;
    // One toe on a narrow shelf: allowed except on indices 34/36 (no relaxed hang past lip). Tile 1 uses tighter |vsp|.
    var _vsp_toler = SHELF_STAND_VSP_ABS_MAX;
    if (_shelf_touch_tile1) _vsp_toler = min(_vsp_toler, SHELF_STAND_VSP_TILE1);
    var touch_stand_for_ground = touch_stand_majority
        || (!_shelf_strict_34_36 && _feet_on_cap_cell && touch_floor_any && (_stand_l || _stand_c || _stand_r) && abs(vsp) <= _vsp_toler);
    // Shelf caps: (a) center misses but 2+ floor probes hit in nearby columns, or (b) bbox is wider than the
    // lip so only 1 probe at feet+1 hits — still treat as anchored when both feet are in the same/adjacent
    // tile column and stand-majority says we're on solid (prevents idle vs hair flipping mid-ledge).
    var _touch_floor_anchor = touch_floor_center;
    if (!_touch_floor_anchor && !_shelf_strict_34_36 && _feet_on_cap_cell && _tm_lc != noone) {
        if (_raw_support_n >= GROUND_LAND_VOTES_MIN_AIR) {
            var _cxl_a = tilemap_get_cell_x_at_pixel(_tm_lc, p_left, _floor_probe_y);
            var _cxc_a = tilemap_get_cell_x_at_pixel(_tm_lc, p_center, _floor_probe_y);
            var _cxr_a = tilemap_get_cell_x_at_pixel(_tm_lc, p_right, _floor_probe_y);
            if (max(_cxl_a, max(_cxc_a, _cxr_a)) - min(_cxl_a, min(_cxc_a, _cxr_a)) <= CAP_GROUND_CELL_SPAN_MAX) {
                _touch_floor_anchor = true;
            }
        }
        if (!_touch_floor_anchor && touch_stand_for_ground && touch_floor_any) {
            var _sx_la = tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y);
            var _sx_ra = tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y);
            if (abs(_sx_la - _sx_ra) <= CAP_GROUND_CELL_SPAN_MAX) _touch_floor_anchor = true;
        }
    }
    // Full blocks: allow anchor when center misses void but inset stand votes + feet span say "on one platform" (lip stand).
    if (!_touch_floor_anchor && !_feet_on_cap_cell && FULL_BLOCK_EDGE_GROUND_FORGIVE && _tm_lc != noone && wall_side == 0
        && touch_stand_for_ground && touch_floor_any) {
        var _s2_span = abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y));
        if (_s2_span <= CAP_GROUND_CELL_SPAN_MAX) _touch_floor_anchor = true;
    }
    var _coyote_floor_refresh = (wall_side == 0) && !((jump_count >= 2) && (!grounded));
    var _thin_cap_ground = _feet_on_cap_cell && (_stand_l || _stand_c || _stand_r) && touch_floor_any && _touch_floor_anchor
        && wall_side == 0 && vsp >= -4;
    
    var _span_feet_s2gv = (_tm_lc != noone) ? abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y)) : 999;
    var _shelf_ground_vote_ok = (_raw_support_n >= GROUND_LAND_VOTES_MIN_AIR)
        || (FULL_BLOCK_EDGE_GROUND_FORGIVE && !_feet_on_cap_cell && touch_floor_any && _raw_support_n >= 1
            && _span_feet_s2gv <= CAP_GROUND_CELL_SPAN_MAX && touch_stand_majority)
        || (!_shelf_strict_34_36 && _feet_on_cap_cell && touch_floor_any && abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y)) <= CAP_GROUND_CELL_SPAN_MAX);
    if ((touch_stand_for_ground && wall_side == 0 && _shelf_ground_vote_ok && _touch_floor_anchor) || _thin_cap_ground || _strict3426_ground) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;
    } else {
        if (touch_floor_any && _coyote_floor_refresh) coyote_time_timer = coyote_time_max;
        if (coyote_time_timer > 0) coyote_time_timer--;
        else grounded = false;
        if ((!touch_stand_for_ground || !_shelf_ground_vote_ok || !_touch_floor_anchor)
            && !(_feet_on_cap_cell && _touch_floor_anchor && touch_floor_any && (_stand_l || _stand_c || _stand_r))) {
            grounded = false;
        }
    }
    if (wall_side == 0 && abs(vsp) < EDGE_GROUND_VSP_MAX && abs(hsp) < MOVEMENT_THRESHOLD && !touch_stand_for_ground && !_thin_cap_ground &&
        _shelf_ground_vote_ok && _touch_floor_anchor) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
    }

    // --- 2b. WALL CLING DETECTION — only when in air and feet not on ground (no cling over ledges) ---
    if (wall_jump_lock > 0) wall_jump_lock--;
    if (wall_jump_extend_timer > 0) wall_jump_extend_timer--;
    // During wall-jump lock, never allow re-stick (especially at top corners where probes can flicker).
    if (wall_jump_lock > 0) {
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
    }
    // While sliding down, allow cling indefinitely. Only forbid cling during wall-jump lock and at the top lip corner itself.
    if (!grounded && !attacking && wall_jump_lock <= 0) {
        if (touch_floor_majority) {
            wall_side = 0;
            wall_cling_grace = 0;
            wall_cling_frames = 0;
        } else {
            var _wall_L1 = floor(bbox_left) - 1;
            var _wall_L2 = floor(bbox_left) - 2;
            var _wall_R1 = floor(bbox_right) + 1;
            var _wall_R2 = floor(bbox_right) + 2;
            var _wall_at_head_left  = check_tile_collision_wall_cling_surface(_wall_L1, head_y) || check_tile_collision_wall_cling_surface(_wall_L2, head_y);
            var _wall_at_head_right = check_tile_collision_wall_cling_surface(_wall_R1, head_y) || check_tile_collision_wall_cling_surface(_wall_R2, head_y);
            var _wall_at_body_left  = check_tile_collision_wall_cling_surface(_wall_L1, center_y) || check_tile_collision_wall_cling_surface(_wall_L1, feet_y) ||
                                      check_tile_collision_wall_cling_surface(_wall_L2, center_y) || check_tile_collision_wall_cling_surface(_wall_L2, feet_y);
            var _wall_at_body_right = check_tile_collision_wall_cling_surface(_wall_R1, center_y) || check_tile_collision_wall_cling_surface(_wall_R1, feet_y) ||
                                      check_tile_collision_wall_cling_surface(_wall_R2, center_y) || check_tile_collision_wall_cling_surface(_wall_R2, feet_y);
            var _wall_left  = _wall_at_head_left && _wall_at_body_left;
            var _wall_right = _wall_at_head_right && _wall_at_body_right;
            var _bt_wall = floor(bbox_top);
            var _bf_wall = floor(bbox_bottom);
            var _scan_y0 = _bt_wall - WALL_CLING_SCAN_ABOVE_HEAD;
            var _col_l_first = noone;
            var _col_r_first = noone;
            for (var _wy = _scan_y0; _wy <= _bf_wall; _wy++) {
                if (_col_l_first == noone && (check_tile_collision_wall_cling_surface(_wall_L1, _wy) || check_tile_collision_wall_cling_surface(_wall_L2, _wy))) {
                    _col_l_first = _wy;
                }
                if (_col_r_first == noone && (check_tile_collision_wall_cling_surface(_wall_R1, _wy) || check_tile_collision_wall_cling_surface(_wall_R2, _wy))) {
                    _col_r_first = _wy;
                }
            }
            var _max_top = _bt_wall + WALL_CLING_COLUMN_MAX_BELOW_TOP;
            if (_wall_left && (_col_l_first == noone || _col_l_first > _max_top)) _wall_left = false;
            if (_wall_right && (_col_r_first == noone || _col_r_first > _max_top)) _wall_right = false;
            var _tmw = global.tilemap_collision_id;
            if (_wall_left && tilemap_wall_cling_under_cap_overhang(_tmw, _wall_L2, _col_l_first)) _wall_left = false;
            if (_wall_right && tilemap_wall_cling_under_cap_overhang(_tmw, _wall_R2, _col_r_first)) _wall_right = false;
            // Top-corner case: when bbox_bottom is within the ledge window of a top surface on this wall column,
            // treating it as a wall-slide target causes wall_side to flicker (ground/lip vs wall) and "stick" the player.
            // Do not allow wall cling when we're near a mountable top lip.
            if (_tmw != noone) {
                // Clear top-no-cling once we've fallen below the stored threshold.
                if (wall_top_no_cling_y_left != noone && bbox_bottom > wall_top_no_cling_y_left) wall_top_no_cling_y_left = noone;
                if (wall_top_no_cling_y_right != noone && bbox_bottom > wall_top_no_cling_y_right) wall_top_no_cling_y_right = noone;

                var _near_top_left = _wall_left && tilemap_horizontal_ledge_mount_priority(_tmw, _wall_L2, bbox_bottom, _bt_wall, _bf_wall, HORIZONTAL_LEDGE_WINDOW_PX);
                var _near_top_right = _wall_right && tilemap_horizontal_ledge_mount_priority(_tmw, _wall_R2, bbox_bottom, _bt_wall, _bf_wall, HORIZONTAL_LEDGE_WINDOW_PX);
                // Top corner: never start or keep wall cling here (prevents "stuck at the top" + animation snapping).
                // Only block STARTING a wall cling at the top corner. If you're already clinging and sliding down,
                // keep it stable (prevents cling↔fall toggling while descending).
                if (_near_top_left && wall_side == 0) {
                    _wall_left = false;
                    wall_cling_grace = 0;
                    wall_cling_frames = 0;
                    // Nudge out of the corner snag so we don't re-trigger this every frame.
                    if (key_left && !key_right) { x += 1; hsp = 0; runMomentum = 0; }
                    // Block cling until we're clearly below this tile top.
                    var _th = tilemap_get_tile_height(_tmw);
                    var _tcy = tilemap_get_cell_y_at_pixel(_tmw, _wall_L2, bbox_bottom);
                    var _cell_top = tilemap_get_y(_tmw) + _tcy * _th;
                    wall_top_no_cling_y_left = _cell_top + HORIZONTAL_LEDGE_WINDOW_PX + WALL_TOP_NO_CLING_EXIT_PAD_PX;
                }
                if (_near_top_right && wall_side == 0) {
                    _wall_right = false;
                    wall_cling_grace = 0;
                    wall_cling_frames = 0;
                    // Nudge out of the corner snag so we don't re-trigger this every frame.
                    if (key_right && !key_left) { x -= 1; hsp = 0; runMomentum = 0; }
                    // Block cling until we're clearly below this tile top.
                    var _th2 = tilemap_get_tile_height(_tmw);
                    var _tcy2 = tilemap_get_cell_y_at_pixel(_tmw, _wall_R2, bbox_bottom);
                    var _cell_top2 = tilemap_get_y(_tmw) + _tcy2 * _th2;
                    wall_top_no_cling_y_right = _cell_top2 + HORIZONTAL_LEDGE_WINDOW_PX + WALL_TOP_NO_CLING_EXIT_PAD_PX;
                }
            }

            // Apply stored top-no-cling hysteresis (prevents near_top flicker from enabling cling every other frame).
            if (wall_side == 0) {
                if (wall_top_no_cling_y_left != noone && bbox_bottom <= wall_top_no_cling_y_left) _wall_left = false;
                if (wall_top_no_cling_y_right != noone && bbox_bottom <= wall_top_no_cling_y_right) _wall_right = false;
            }

            var _can_cling = (vsp >= wall_cling_vsp_min);
            var _can_cling_left  = _can_cling && _wall_left && key_left;
            var _can_cling_right = _can_cling && _wall_right && key_right;
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
                if (wall_side == -1 && !_wall_left) {
                    wall_side = 0;
                    wall_cling_grace = 0;
                    wall_cling_frames = 0;
                } else if (wall_side == 1 && !_wall_right) {
                    wall_side = 0;
                    wall_cling_grace = 0;
                    wall_cling_frames = 0;
                }
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
    if (wall_side != 0 && !touch_floor_majority) grounded = false;
    if (wall_side != 0 && !_touch_floor_anchor) grounded = false;

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
        if (key_dash && dash_cooldown <= 0 && grounded && !attacking && sprite_index != spr_mc_jump
            && sprite_index != spr_mc_attack2 && sprite_index != spr_asta_attack1) {
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
                var _walk_scale = 1;
                if (post_attack_accel_timer > 0) {
                    _walk_scale = 1 - post_attack_accel_timer / POST_ATTACK_ACCEL_FRAMES;
                    if (_walk_scale < 0.35) _walk_scale = 0.35;
                }
                hsp = walksp * inputDir * _walk_scale;
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

    global.player_move_vsp = vsp;

    // --- 5. COLLISIONS (Horizontal) ---
    if (hsp != 0) {
        var _h_step = sign(hsp);
        var _target_side = (hsp > 0) ? floor(bbox_right) : floor(bbox_left);
        var _tm_h = global.tilemap_collision_id;
        var _bb_bot_h = bbox_bottom;
    
        // Always do pixel-stepped movement for robustness (prevents tunneling if speeds increase later).
        repeat(abs(ceil(hsp))) {
            // Re-sample bounds each step (sprite/mask can change; x/y can change)
            feet_y    = floor(bbox_bottom);
            head_y    = floor(bbox_top);
            center_y  = floor((bbox_top + bbox_bottom) * 0.5);
            p_left    = floor(bbox_left) + 1;
            p_right   = floor(bbox_right) - 1;
            p_center  = floor((bbox_left + bbox_right) * 0.5);
            var _ledge_center_ok = check_tile_collision(p_center, feet_y + GROUND_CHECK_DIST);

            _target_side = (hsp > 0) ? floor(bbox_right) : floor(bbox_left);

            // Ledge mount priority: if any sample on the wall column is solid with bbox_bottom in the ledge window, skip wall rejection for this step.
            var _wx = _target_side + _h_step;
            var _y_h = head_y + WALL_CHECK_OFFSET;
            var _y_t = feet_y - LEDGE_TOE_INSET;
            // Do not allow "ledge mount priority" while wall-jump locking away from a wall.
            // At the top of walls, this can behave like a tiny corner catch and cancel the jump-out.
            var _ledge_mount = false;
            if (!(wall_jump_lock > 0 && !grounded)) {
                _ledge_mount = tilemap_horizontal_ledge_mount_priority(_tm_h, _wx, _bb_bot_h, min(_y_h, center_y, _y_t), max(_y_h, center_y, _y_t), HORIZONTAL_LEDGE_WINDOW_PX);
            }
            var _w_led = HORIZONTAL_LEDGE_WINDOW_PX;
            var _air_fb_face = (!grounded) && (
                tilemap_horizontal_full_block_side_face_at(_tm_h, _wx, _y_h, _bb_bot_h, _w_led) ||
                tilemap_horizontal_full_block_side_face_at(_tm_h, _wx, center_y, _bb_bot_h, _w_led) ||
                tilemap_horizontal_full_block_side_face_at(_tm_h, _wx, _y_t, _bb_bot_h, _w_led));

            if (_ledge_mount && !_air_fb_face) {
                x += _h_step;
            } else {
                var _blk_h = tilemap_horizontal_side_probe_blocks(_tm_h, _wx, _y_h, _bb_bot_h, HORIZONTAL_LEDGE_WINDOW_PX);
                var _blk_c = tilemap_horizontal_side_probe_blocks(_tm_h, _wx, center_y, _bb_bot_h, HORIZONTAL_LEDGE_WINDOW_PX);
                var _blk_t = tilemap_horizontal_side_probe_blocks(_tm_h, _wx, _y_t, _bb_bot_h, HORIZONTAL_LEDGE_WINDOW_PX);
                var _clear = (!_blk_h && !_blk_c && !_blk_t);
                if (_air_fb_face) _clear = false;

                if (_clear) {
                    x += _h_step;
                } else {
                    // --- Ledge/corner correction: step up 1–LEDGE_STEP_MAX px if blocked by small lip ---
                    var _stepped = false;
                    if (grounded && vsp >= 0 && !attacking && _ledge_center_ok) {
                        for (var _step_up = 1; _step_up <= LEDGE_STEP_MAX; _step_up++) {
                            var _feet_y_u   = feet_y   - _step_up;
                            var _head_y_u   = head_y   - _step_up;
                            var _center_y_u = center_y - _step_up;

                            var _ceiling_clear = !check_tile_collision(p_left,   _head_y_u, true, _feet_y_u) &&
                                                 !check_tile_collision(p_center, _head_y_u, true, _feet_y_u) &&
                                                 !check_tile_collision(p_right,  _head_y_u, true, _feet_y_u);

                            if (_ceiling_clear &&
                                !check_tile_collision(_target_side + _h_step, _head_y_u + WALL_CHECK_OFFSET, true, _feet_y_u) &&
                                !check_tile_collision(_target_side + _h_step, _center_y_u, true, _feet_y_u) &&
                                !check_tile_collision(_target_side + _h_step, _feet_y_u - LEDGE_TOE_INSET, true, _feet_y_u)) {
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
    }

    // --- 5c. DE-PENETRATE (torso or feet inside full block — recover bad clips; run grounded or not) ---
    if (global.tilemap_collision_id != noone) {
        var _tm_dp = global.tilemap_collision_id;
        var _ly_e = FULL_BLOCK_FEET_INTERIOR_LY_MIN;
        repeat (16) {
            var _fy_dp = floor(bbox_bottom);
            var _pc_dp = floor((bbox_left + bbox_right) * 0.5);
            var _mid_dp = floor((bbox_top + bbox_bottom) * 0.5);
            var _pl_dp = floor(bbox_left) + 1;
            var _pr_dp = floor(bbox_right) - 1;
            var _bl_dp = floor(bbox_left);
            var _br_dp = floor(bbox_right);
            var _tor_dp = check_tile_collision(_pc_dp, _mid_dp);
            var _fe_l = tilemap_point_full_block_feet_embedded(_tm_dp, _bl_dp, _fy_dp, _ly_e);
            var _fe_r = tilemap_point_full_block_feet_embedded(_tm_dp, _br_dp, _fy_dp, _ly_e);
            if (!_tor_dp && !_fe_l && !_fe_r) break;
            var _dir_dp = -sign(hsp);
            if (_fe_l && !_fe_r) _dir_dp = 1;
            else if (_fe_r && !_fe_l) _dir_dp = -1;
            if (_dir_dp == 0) _dir_dp = -sign(key_right - key_left);
            if (_dir_dp == 0) _dir_dp = -last_direction;
            if (_dir_dp == 0) _dir_dp = -1;
            x += _dir_dp;
            hsp = 0;
            runMomentum = 0;
        }
    }

    // --- 6. COLLISIONS (Vertical) ---
    feet_y    = floor(bbox_bottom);
    head_y    = floor(bbox_top);
    center_y  = floor((bbox_top + bbox_bottom) * 0.5);
    p_left    = floor(bbox_left) + 1;
    p_right   = floor(bbox_right) - 1;
    p_center  = floor((bbox_left + bbox_right) * 0.5);

    // One-way ledges: threshold when falling (vsp>0); side-entry = _is_tapping (immediate) OR passive vsp+air gates.
    var _tm_s6 = global.tilemap_collision_id;
    var _mag_thr = (stunTimer <= 0) ? clamp(key_right - key_left, -1, 1) : 0;
    var _shelf_snap_dy = noone;
    if (_tm_s6 != noone && vsp > 0) {
        _shelf_snap_dy = tilemap_shelf_threshold_land_dy(_tm_s6, p_left, p_center, p_right, bbox_bottom, shelf_bb_bottom_prev, vsp, _mag_thr);
    }
    var _is_tapping = (key_right && !key_left) || (key_left && !key_right);
    var _side_entry_ok = _is_tapping || (vsp > SIDE_ENTRY_MIN_VSP && side_entry_airborne_frames >= SIDE_ENTRY_MIN_AIR_FRAMES);
    if (_shelf_snap_dy == noone && _tm_s6 != noone && !grounded && vsp >= 0 && _side_entry_ok) {
        var _ledge_h_intent = (stunTimer <= 0) ? clamp(key_right - key_left, -1, 1) : 0;
        if (_ledge_h_intent == 0) _ledge_h_intent = sign(hsp);
        _shelf_snap_dy = tilemap_shelf_side_entry_land_dy(_tm_s6, p_left, p_center, p_right, bbox_bottom, SIDE_ENTRY_CATCH_WINDOW_PX, _ledge_h_intent, (bbox_left + bbox_right) * 0.5);
    }
    if (_shelf_snap_dy != noone) {
        y += _shelf_snap_dy;
        vsp = 0;
        grounded = true;
        player_movement_state = PLAYER_STATE_LAND;
        shelf_threshold_snap_this_step = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;
        global.player_ledge_bb_prev = bbox_bottom;
    }
    feet_y    = floor(bbox_bottom);
    head_y    = floor(bbox_top);
    center_y  = floor((bbox_top + bbox_bottom) * 0.5);
    p_left    = floor(bbox_left) + 1;
    p_right   = floor(bbox_right) - 1;
    p_center  = floor((bbox_left + bbox_right) * 0.5);

    if (vsp != 0) {
        var _v_step = sign(vsp);
        repeat(abs(ceil(vsp))) {
            var _check_y = (_v_step < 0) ? head_y : feet_y;
            var _col_clear;
            if (!grounded && _v_step > 0) {
                var _foot_probe_y = _check_y + _v_step;
                var _tmv = global.tilemap_collision_id;
                // Strict 34/36 often leave grounded false while feet sit on the cap; do not use ignore_shelf here
                // or gravity tunnels through the same way it used to on 1/5.
                var _shelf_support_feet = (_tmv != noone) && tilemap_shelf_cap_near_feet(_tmv, p_left, p_center, p_right, feet_y);
                if (_shelf_support_feet) {
                    _col_clear = !check_tile_collision(p_left, feet_y + _v_step, false, noone, false) &&
                        !check_tile_collision(p_center, feet_y + _v_step, false, noone, false) &&
                        !check_tile_collision(p_right, feet_y + _v_step, false, noone, false);
                } else {
                    var _thin_row_ahead = (_tmv != noone) && (
                        tilemap_cell_thin_floor_tile(_tmv, p_left, _foot_probe_y) ||
                        tilemap_cell_thin_floor_tile(_tmv, p_center, _foot_probe_y) ||
                        tilemap_cell_thin_floor_tile(_tmv, p_right, _foot_probe_y));
                    if (_thin_row_ahead) {
                        _col_clear = !check_tile_collision(p_left, _foot_probe_y, false, noone, true) &&
                            !check_tile_collision(p_center, _foot_probe_y, false, noone, true) &&
                            !check_tile_collision(p_right, _foot_probe_y, false, noone, true);
                    } else {
                        // Mega Man–style: use all three foot columns when falling onto solid (not thin shelf).
                        // Center-only allowed one foot to enter the tile before the center probe fired — corner / lip jitter + landing lock.
                        // But when stepping off a ledge, a single toe can linger over the tile and cancel gravity for a few frames.
                        // Use inset foot probes here so you drop as soon as your stance leaves the platform.
                        var _fall_inset = (variable_instance_exists(id, "AIR_FALL_EDGE_INSET") ? AIR_FALL_EDGE_INSET : GROUND_PROBE_EDGE_INSET);
                        _fall_inset = max(_fall_inset, GROUND_PROBE_EDGE_INSET);
                        var _pl_fall = floor(bbox_left) + _fall_inset;
                        var _pr_fall = floor(bbox_right) - _fall_inset;
                        if (_pl_fall >= _pr_fall) {
                            _pl_fall = p_left;
                            _pr_fall = p_right;
                        }
                        _col_clear = !check_tile_collision(_pl_fall, _foot_probe_y, false, noone, true) &&
                            !check_tile_collision(p_center, _foot_probe_y, false, noone, true) &&
                            !check_tile_collision(_pr_fall, _foot_probe_y, false, noone, true);
                    }
                }
            } else {
                var _rise_tile = (_v_step < 0);
                if (_v_step > 0) {
                    // While grounded — or feet on a one-way shelf cap with grounded false (34/36 lip) — do not ignore
                    // shelf tiles downward; gravity still adds vsp each frame.
                    var _tmvd = global.tilemap_collision_id;
                    var _shelf_support_else = (_tmvd != noone) && tilemap_shelf_cap_near_feet(_tmvd, p_left, p_center, p_right, feet_y);
                    var _ig_shelf_down = !grounded && !_shelf_support_else;
                    _col_clear = !check_tile_collision(p_left, feet_y + _v_step, false, noone, _ig_shelf_down) &&
                        !check_tile_collision(p_center, feet_y + _v_step, false, noone, _ig_shelf_down) &&
                        !check_tile_collision(p_right, feet_y + _v_step, false, noone, _ig_shelf_down);
                } else {
                    _col_clear = !check_tile_collision(p_left,   _check_y + _v_step, _rise_tile, feet_y) &&
                        !check_tile_collision(p_center, _check_y + _v_step, _rise_tile, feet_y) &&
                        !check_tile_collision(p_right,  _check_y + _v_step, _rise_tile, feet_y);
                }
            }
            if (_col_clear) {
                y += _v_step;
                feet_y   = floor(bbox_bottom);
                head_y   = floor(bbox_top);
                center_y = floor((bbox_top + bbox_bottom) * 0.5);
                p_left   = floor(bbox_left) + 1;
                p_right  = floor(bbox_right) - 1;
                p_center = floor((bbox_left + bbox_right) * 0.5);
            } else {
                if (_v_step > 0) {
                    var _led_snap = tilemap_ledge_down_snap_dy(global.tilemap_collision_id, p_left, p_center, p_right, feet_y + _v_step, bbox_bottom);
                    if (_led_snap != noone) {
                        y += _led_snap;
                        vsp = 0;
                        grounded = true;
                        coyote_time_timer = coyote_time_max;
                        jump_count = 0;
                        wall_side = 0;
                        wall_cling_grace = 0;
                        wall_cling_frames = 0;
                        wall_jump_last_side = 0;
                        shelf_threshold_snap_this_step = true;
                        global.player_ledge_bb_prev = bbox_bottom;
                    } else {
                        // Keep y float — do not floor/ceil here (thin ledge rest + sub-pixel snap).
                    }
                } else {
                    // Ceiling / upward stop: zero vsp only (avoid ceil(y) stripping float contact).
                }
                vsp = 0;
                break;
            }
        }
    }

    // --- 6b. FEET POP (full block: rest on top surface, not inside body — fixes corner sink + landing pose jitter) ---
    if (global.tilemap_collision_id != noone) {
        var _tm_pop = global.tilemap_collision_id;
        var _ly_pop = FULL_BLOCK_FEET_INTERIOR_LY_MIN;
        feet_y = floor(bbox_bottom);
        var _pl_pop = floor(bbox_left) + 1;
        var _pr_pop = floor(bbox_right) - 1;
        var _pc_pop = floor((bbox_left + bbox_right) * 0.5);
        var _bl_pop = floor(bbox_left);
        var _br_pop = floor(bbox_right);
        if (tilemap_any_feet_row_full_block_embedded(_tm_pop, _pl_pop, _pc_pop, _pr_pop, _bl_pop, _br_pop, feet_y, _ly_pop)) {
            full_lip_anim_sticky = 0;
            repeat (12) {
                y -= 1;
                feet_y = floor(bbox_bottom);
                if (!tilemap_any_feet_row_full_block_embedded(_tm_pop, _pl_pop, _pc_pop, _pr_pop, floor(bbox_left), floor(bbox_right), feet_y, _ly_pop)) break;
            }
        }
    }

    // --- 6d. PEEL OUT OF TILEMAP (airborne wide bbox vs ledge lip) ---
    if (global.tilemap_collision_id != noone && !grounded && wall_side == 0) {
        var _ft_pd = floor(bbox_bottom);
        var _pl_pd = floor(bbox_left) + 1;
        var _pr_pd = floor(bbox_right) - 1;
        var _pc_pd = floor((bbox_left + bbox_right) * 0.5);
        var _fpys_pd = _ft_pd + GROUND_CHECK_DIST;
        var _tm_pd = global.tilemap_collision_id;
        var _cap_pd = (_tm_pd != noone) && tilemap_cell_thin_floor_near_feet(_tm_pd, _pc_pd, _ft_pd);
        var _rc_pd = check_tile_collision(_pc_pd, _fpys_pd);
        var _rl_pd = check_tile_collision(_pl_pd, _fpys_pd);
        var _rr_pd = check_tile_collision(_pr_pd, _fpys_pd);
        var _sp_pd = 999;
        if (_tm_pd != noone) {
            _sp_pd = abs(tilemap_get_cell_x_at_pixel(_tm_pd, _pl_pd, _ft_pd) - tilemap_get_cell_x_at_pixel(_tm_pd, _pr_pd, _ft_pd));
        }
        var _skip_peel_full_teeter = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap_pd && !_rc_pd && (_rl_pd || _rr_pd) && _sp_pd <= CAP_GROUND_CELL_SPAN_MAX;
        var _torso_pd = check_tile_collision(_pc_pd, floor((bbox_top + bbox_bottom) * 0.5));
        var _feet_pd_embed = tilemap_any_feet_row_full_block_embedded(_tm_pd, _pl_pd, _pc_pd, _pr_pd, floor(bbox_left), floor(bbox_right), _ft_pd, FULL_BLOCK_FEET_INTERIOR_LY_MIN);
        _skip_peel_full_teeter = _skip_peel_full_teeter && !_torso_pd && !_feet_pd_embed;
        if (!_skip_peel_full_teeter) {
        repeat (TILEMAP_AIR_SEPARATION_MAX) {
            feet_y = floor(bbox_bottom);
            head_y = floor(bbox_top);
            p_left = floor(bbox_left) + 1;
            p_right = floor(bbox_right) - 1;
            p_center = floor((bbox_left + bbox_right) * 0.5);
            var _fy0 = feet_y;
            var _fy1 = feet_y - 1;
            var _hit_c = check_tile_collision(p_center, _fy0) || check_tile_collision(p_center, _fy1);
            var _hit_l = check_tile_collision(p_left,   _fy0) || check_tile_collision(p_left,   _fy1);
            var _hit_r = check_tile_collision(p_right,  _fy0) || check_tile_collision(p_right,  _fy1);
            var _tm_peel = global.tilemap_collision_id;
            var _cap_peel = (_tm_peel != noone) && (
                tilemap_cell_thin_floor_tile(_tm_peel, p_left, _fy0) || tilemap_cell_thin_floor_tile(_tm_peel, p_left, _fy1) ||
                tilemap_cell_thin_floor_tile(_tm_peel, p_center, _fy0) || tilemap_cell_thin_floor_tile(_tm_peel, p_center, _fy1) ||
                tilemap_cell_thin_floor_tile(_tm_peel, p_right, _fy0) || tilemap_cell_thin_floor_tile(_tm_peel, p_right, _fy1));
            var _full_top_peel = (_tm_peel != noone) && (
                tilemap_point_full_block_top_band(_tm_peel, p_left, _fy0, FULL_BLOCK_TOP_PEEL_BAND_PX) ||
                tilemap_point_full_block_top_band(_tm_peel, p_left, _fy1, FULL_BLOCK_TOP_PEEL_BAND_PX) ||
                tilemap_point_full_block_top_band(_tm_peel, p_center, _fy0, FULL_BLOCK_TOP_PEEL_BAND_PX) ||
                tilemap_point_full_block_top_band(_tm_peel, p_center, _fy1, FULL_BLOCK_TOP_PEEL_BAND_PX) ||
                tilemap_point_full_block_top_band(_tm_peel, p_right, _fy0, FULL_BLOCK_TOP_PEEL_BAND_PX) ||
                tilemap_point_full_block_top_band(_tm_peel, p_right, _fy1, FULL_BLOCK_TOP_PEEL_BAND_PX));
            var _soft_peel = _cap_peel || _full_top_peel;
            if (!_hit_l && !_hit_r && !_hit_c) break;
            // Thin shelf/cap or full-block top band: avoid y-- pop when teetering the lip; lateral or stop.
            if (_hit_c) {
                if (!_soft_peel) {
                    y -= 1;
                } else if (_hit_l && !_hit_r) {
                    x += 1;
                } else if (_hit_r && !_hit_l) {
                    x -= 1;
                } else {
                    break;
                }
            } else if (_hit_l && !_hit_r) {
                if (_soft_peel) break;
                x += 1;
            } else if (_hit_r && !_hit_l) {
                if (_soft_peel) break;
                x -= 1;
            } else if (_hit_l && _hit_r) {
                if (_soft_peel) break;
                y -= 1;
            } else break;
        }
        feet_y = floor(bbox_bottom);
        head_y = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        p_left = floor(bbox_left) + 1;
        p_right = floor(bbox_right) - 1;
        p_center = floor((bbox_left + bbox_right) * 0.5);
        } else {
        feet_y = floor(bbox_bottom);
        head_y = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        p_left = floor(bbox_left) + 1;
        p_right = floor(bbox_right) - 1;
        p_center = floor((bbox_left + bbox_right) * 0.5);
        }
    }

    // --- 6a. GROUND SNAP ---
    if (global.tilemap_collision_id != noone && vsp == 0 && wall_side == 0) {
        feet_y = floor(bbox_bottom);
        var _pl0 = floor(bbox_left) + 1;
        var _pr0 = floor(bbox_right) - 1;
        var _pc0 = floor((bbox_left + bbox_right) * 0.5);
        var _skip_6a_ledges = (_tm_lc != noone) && tilemap_shelf_cap_near_feet(_tm_lc, _pl0, _pc0, _pr0, feet_y);
        if (!_skip_6a_ledges) {
        var _fpy6a = feet_y + GROUND_CHECK_DIST;
        var _cap6a = (_tm_lc != noone) && tilemap_cell_thin_floor_near_feet(_tm_lc, _pc0, feet_y);
        var _rawc6a = check_tile_collision(_pc0, _fpy6a);
        var _rawl6a = check_tile_collision(_pl0, _fpy6a);
        var _rawr6a = check_tile_collision(_pr0, _fpy6a);
        var _span6a = 999;
        if (global.tilemap_collision_id != noone) {
            _span6a = abs(tilemap_get_cell_x_at_pixel(global.tilemap_collision_id, _pl0, feet_y) - tilemap_get_cell_x_at_pixel(global.tilemap_collision_id, _pr0, feet_y));
        }
        var _teeter6a_skip = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap6a && !_rawc6a && (_rawl6a || _rawr6a) && _span6a <= CAP_GROUND_CELL_SPAN_MAX;
        var _torso_6a = check_tile_collision(_pc0, floor((bbox_top + bbox_bottom) * 0.5));
        var _feet_6a_embed = tilemap_any_feet_row_full_block_embedded(global.tilemap_collision_id, _pl0, _pc0, _pr0, floor(bbox_left), floor(bbox_right), feet_y, FULL_BLOCK_FEET_INTERIOR_LY_MIN);
        _teeter6a_skip = _teeter6a_skip && !_torso_6a && !_feet_6a_embed;
        if (!_teeter6a_skip) {
        var _thin_snap_6a = (_tm_lc != noone) && (
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pc0, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pl0, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pr0, feet_y));
        var _snap_budget_6a = _thin_snap_6a ? GROUND_SNAP_THIN_CAP_MAX : GROUND_SNAP_MAX;
        repeat (GROUND_SNAP_MAX) {
            if (_snap_budget_6a <= 0) break;
            feet_y = floor(bbox_bottom);
            var _pl_snap = floor(bbox_left) + 1;
            var _pr_snap = floor(bbox_right) - 1;
            var _pc_snap = floor((bbox_left + bbox_right) * 0.5);
            var _feet_c = check_tile_collision(_pc_snap, feet_y);
            var _feet_l = check_tile_collision(_pl_snap, feet_y);
            var _feet_r = check_tile_collision(_pr_snap, feet_y);
            var _snap_on_cap = (_tm_lc != noone) && (
                tilemap_cell_thin_floor_near_feet(_tm_lc, _pc_snap, feet_y) ||
                tilemap_cell_thin_floor_near_feet(_tm_lc, _pl_snap, feet_y) ||
                tilemap_cell_thin_floor_near_feet(_tm_lc, _pr_snap, feet_y));
            if (_snap_on_cap) {
                var _u1_flush = check_tile_collision(_pc_snap, feet_y + GROUND_CHECK_DIST) ||
                    check_tile_collision(_pl_snap, feet_y + GROUND_CHECK_DIST) ||
                    check_tile_collision(_pr_snap, feet_y + GROUND_CHECK_DIST);
                if (_u1_flush && !_feet_c && !_feet_l && !_feet_r) break;
                if (_feet_c || _feet_l || _feet_r) break;
            } else if (_feet_c || _feet_l || _feet_r) {
                break;
            }
            var _u1_c = check_tile_collision(_pc_snap, feet_y + GROUND_CHECK_DIST);
            var _u1_l = check_tile_collision(_pl_snap, feet_y + GROUND_CHECK_DIST);
            var _u1_r = check_tile_collision(_pr_snap, feet_y + GROUND_CHECK_DIST);
            if (_u1_c || _u1_l || _u1_r) {
                y += 1;
                _snap_budget_6a--;
                continue;
            }
            var _found_below = false;
            for (var _d = 2; _d <= GROUND_SNAP_PROBE_DEPTH; _d++) {
                if (check_tile_collision(_pc_snap, feet_y + _d) ||
                    check_tile_collision(_pl_snap, feet_y + _d) ||
                    check_tile_collision(_pr_snap, feet_y + _d)) {
                    _found_below = true;
                    break;
                }
            }
            if (!_found_below) break;
            y += 1;
            _snap_budget_6a--;
        }
        }
        }
    }

    // --- 5b. WALL CLING: pop out of solid, then snap flush to wall ---
    if (wall_side != 0) {
        var _wy = floor((bbox_top + bbox_bottom) * 0.5);
        if (wall_side == -1 && check_tile_collision(floor(bbox_left), _wy)) x += 1;
        if (wall_side == 1  && check_tile_collision(floor(bbox_right), _wy)) x -= 1;
        feet_y   = floor(bbox_bottom);
        head_y   = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        repeat (WALL_CLING_SNAP_ITER_MAX) {
            feet_y   = floor(bbox_bottom);
            head_y   = floor(bbox_top);
            center_y = floor((bbox_top + bbox_bottom) * 0.5);
            if (wall_side == -1) {
                var _in_l = check_tile_collision(floor(bbox_left), feet_y) || check_tile_collision(floor(bbox_left), center_y) ||
                    check_tile_collision(floor(bbox_left), head_y + WALL_CHECK_OFFSET);
                if (_in_l) {
                    x += 1;
                    continue;
                }
                var _flush_l = check_tile_collision(floor(bbox_left) - 1, feet_y) || check_tile_collision(floor(bbox_left) - 1, center_y) ||
                    check_tile_collision(floor(bbox_left) - 1, head_y + WALL_CHECK_OFFSET);
                if (_flush_l) break;
                x -= 1;
            } else {
                var _in_r = check_tile_collision(floor(bbox_right), feet_y) || check_tile_collision(floor(bbox_right), center_y) ||
                    check_tile_collision(floor(bbox_right), head_y + WALL_CHECK_OFFSET);
                if (_in_r) {
                    x -= 1;
                    continue;
                }
                var _flush_r = check_tile_collision(floor(bbox_right) + 1, feet_y) || check_tile_collision(floor(bbox_right) + 1, center_y) ||
                    check_tile_collision(floor(bbox_right) + 1, head_y + WALL_CHECK_OFFSET);
                if (_flush_r) break;
                x += 1;
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
    var _feet_y_now = floor(bbox_bottom);
    var _p_left_now   = floor(bbox_left) + 1;
    var _p_right_now  = floor(bbox_right) - 1;
    var _p_center_now = floor((bbox_left + bbox_right) * 0.5);
    var _pgl_now = floor(bbox_left) + GROUND_PROBE_EDGE_INSET;
    var _pgr_now = floor(bbox_right) - GROUND_PROBE_EDGE_INSET;
    if (_pgl_now >= _pgr_now) {
        _pgl_now = _p_left_now;
        _pgr_now = _p_right_now;
    }
    var _stand_c_now = check_floor_standable(_p_center_now, _feet_y_now, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_l_now = check_floor_standable(_pgl_now, _feet_y_now, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_r_now = check_floor_standable(_pgr_now, _feet_y_now, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _fpy_now = _feet_y_now + GROUND_CHECK_DIST;
    var _tm6c = global.tilemap_collision_id;
    var _cap_cell_now = (_tm6c != noone) && (
        tilemap_cell_thin_floor_near_feet(_tm6c, _p_center_now, _feet_y_now) ||
        tilemap_cell_thin_floor_near_feet(_tm6c, _p_left_now, _feet_y_now) ||
        tilemap_cell_thin_floor_near_feet(_tm6c, _p_right_now, _feet_y_now) ||
        tilemap_cell_thin_floor_near_feet(_tm6c, _pgl_now, _feet_y_now) ||
        tilemap_cell_thin_floor_near_feet(_tm6c, _pgr_now, _feet_y_now));
    if (_cap_cell_now) {
        _stand_l_now = check_floor_standable(_p_left_now, _feet_y_now, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
        _stand_r_now = check_floor_standable(_p_right_now, _feet_y_now, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    }
    var _floor_votes_now = (_stand_l_now ? 1 : 0) + (_stand_c_now ? 1 : 0) + (_stand_r_now ? 1 : 0);
    var _raw_floor_now = (check_tile_collision(_p_center_now, _fpy_now) ? 1 : 0) +
        (check_tile_collision(_p_left_now, _fpy_now) ? 1 : 0) +
        (check_tile_collision(_p_right_now, _fpy_now) ? 1 : 0);
    var _raw_floor_any_now = check_tile_collision(_p_center_now, _fpy_now) ||
        check_tile_collision(_p_left_now, _fpy_now) || check_tile_collision(_p_right_now, _fpy_now);
    var _votes_needed = (wall_side != 0) ? GROUND_LAND_VOTES_MIN_CLING : GROUND_LAND_VOTES_MIN_AIR;
    var _ix_ln = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_left_now, _fpy_now) : -1;
    var _ix_cn = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_center_now, _fpy_now) : -1;
    var _ix_rn = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_right_now, _fpy_now) : -1;
    var _shelf_strict_34_36_now = (_ix_ln == 34 || _ix_ln == 36 || _ix_cn == 34 || _ix_cn == 36 || _ix_rn == 34 || _ix_rn == 36);
    var _shelf_cap_feet_6c = (_tm6c != noone) && tilemap_shelf_cap_near_feet(_tm6c, _p_left_now, _p_center_now, _p_right_now, _feet_y_now);
    var _shelf_touch_tile1_now = (_ix_ln == 1 || _ix_cn == 1 || _ix_rn == 1);
    var _vsp_lim_6c = SHELF_STAND_VSP_ABS_MAX;
    if (_shelf_touch_tile1_now) _vsp_lim_6c = min(_vsp_lim_6c, SHELF_STAND_VSP_TILE1);
    var _strict3426_6c = _shelf_strict_34_36_now && _shelf_cap_feet_6c && wall_side == 0
        && _raw_floor_any_now && (_stand_l_now || _stand_c_now || _stand_r_now) && abs(vsp) <= _vsp_lim_6c;
    var _votes_ok_6c = (_floor_votes_now >= _votes_needed)
        || (!_shelf_strict_34_36_now && _cap_cell_now && _raw_floor_any_now && (_stand_l_now || _stand_c_now || _stand_r_now) && abs(vsp) <= _vsp_lim_6c);
    var _center_floor_now = check_tile_collision(_p_center_now, _fpy_now);
    var _center_floor_anchor_now = _center_floor_now;
    var _shelf_raw_ok_now = _raw_floor_now >= GROUND_LAND_VOTES_MIN_AIR
        || (!_shelf_strict_34_36_now && _cap_cell_now && _raw_floor_any_now && _tm6c != noone
            && abs(tilemap_get_cell_x_at_pixel(_tm6c, _p_left_now, _feet_y_now) - tilemap_get_cell_x_at_pixel(_tm6c, _p_right_now, _feet_y_now)) <= CAP_GROUND_CELL_SPAN_MAX);
    if (!_center_floor_anchor_now && !_shelf_strict_34_36_now && _cap_cell_now && _tm6c != noone && _shelf_raw_ok_now) {
        var _cxl6 = tilemap_get_cell_x_at_pixel(_tm6c, _p_left_now, _fpy_now);
        var _cxc6 = tilemap_get_cell_x_at_pixel(_tm6c, _p_center_now, _fpy_now);
        var _cxr6 = tilemap_get_cell_x_at_pixel(_tm6c, _p_right_now, _fpy_now);
        if (max(_cxl6, max(_cxc6, _cxr6)) - min(_cxl6, min(_cxc6, _cxr6)) <= CAP_GROUND_CELL_SPAN_MAX) {
            _center_floor_anchor_now = true;
        }
    }
    if (!_center_floor_anchor_now && !_shelf_strict_34_36_now && _cap_cell_now && _tm6c != noone && _votes_ok_6c && _raw_floor_any_now && (_stand_l_now || _stand_c_now || _stand_r_now)) {
        var _sx_ln = tilemap_get_cell_x_at_pixel(_tm6c, _p_left_now, _feet_y_now);
        var _sx_rn = tilemap_get_cell_x_at_pixel(_tm6c, _p_right_now, _feet_y_now);
        if (abs(_sx_ln - _sx_rn) <= CAP_GROUND_CELL_SPAN_MAX) _center_floor_anchor_now = true;
    }
    var _on_ground_now = false;
    var _mid_y_6c = floor((bbox_top + bbox_bottom) * 0.5);
    var _torso_overlap_6c = check_tile_collision(_p_center_now, _mid_y_6c);
    var _feet_embed_6c = tilemap_any_feet_row_full_block_embedded(_tm6c, _p_left_now, _p_center_now, _p_right_now, floor(bbox_left), floor(bbox_right), _feet_y_now, FULL_BLOCK_FEET_INTERIOR_LY_MIN);
    if (_torso_overlap_6c || _feet_embed_6c) full_lip_anim_sticky = 0;
    if (_cap_cell_now) {
        _on_ground_now = (_votes_ok_6c && _shelf_raw_ok_now
            && _raw_floor_any_now && (_stand_l_now || _stand_c_now || _stand_r_now) && _center_floor_anchor_now)
            || _strict3426_6c;
    } else {
        var _span_lr_full = 999;
        if (_tm6c != noone) {
            _span_lr_full = abs(tilemap_get_cell_x_at_pixel(_tm6c, _p_left_now, _feet_y_now) - tilemap_get_cell_x_at_pixel(_tm6c, _p_right_now, _feet_y_now));
        }
        var _full_lip_ok = FULL_BLOCK_EDGE_GROUND_FORGIVE && _raw_floor_any_now && _raw_floor_now >= 1 && _span_lr_full <= CAP_GROUND_CELL_SPAN_MAX;
        _on_ground_now = (_floor_votes_now >= _votes_needed) && (
            (_raw_floor_now >= GROUND_LAND_VOTES_MIN_AIR && _center_floor_now) ||
            _full_lip_ok
        );
    }
    if (_on_ground_now) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;
    }
    if (shelf_threshold_snap_this_step) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        wall_side = 0;
        wall_cling_grace = 0;
        wall_cling_frames = 0;
        wall_jump_last_side = 0;
    }

    // Full-block lip: animation-only stability (peak/fall probes use center-heavy checks that flicker at the last pixel).
    var _span_lr_ast = 999;
    if (_tm6c != noone && !_cap_cell_now) {
        _span_lr_ast = abs(tilemap_get_cell_x_at_pixel(_tm6c, _p_left_now, _feet_y_now) - tilemap_get_cell_x_at_pixel(_tm6c, _p_right_now, _feet_y_now));
    }
    // Only true "teeter" geometry: center probe misses void while feet still vote — not every full-block stand (span≤1 covers most landings).
    var _lip_ast_refresh = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap_cell_now && !_center_floor_now && _raw_floor_any_now
        && (_stand_l_now || _stand_c_now || _stand_r_now) && _span_lr_ast <= CAP_GROUND_CELL_SPAN_MAX && !_torso_overlap_6c && !_feet_embed_6c;
    if (_lip_ast_refresh) full_lip_anim_sticky = FULL_BLOCK_LIP_ANIM_STICKY_HOLD_FRAMES;
    if (_on_ground_now && _center_floor_now && !_cap_cell_now) {
        full_lip_center_stable_frames++;
        if (full_lip_center_stable_frames >= FULL_BLOCK_LIP_STICKY_CLEAR_CENTER_FRAMES) {
            full_lip_anim_sticky = 0;
        }
    } else {
        full_lip_center_stable_frames = 0;
    }
    if (!grounded && full_lip_anim_sticky > 0) {
        var _lip_air_keep = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap_cell_now && _raw_floor_any_now
            && (_stand_l_now || _stand_c_now || _stand_r_now) && _span_lr_ast <= CAP_GROUND_CELL_SPAN_MAX && !_torso_overlap_6c && !_feet_embed_6c;
        if (!_lip_air_keep) full_lip_anim_sticky--;
    }

    // --- 7. ANIMATION (reverted, cleaned up) ---
    var _input_dir = key_right - key_left;
    var _fy_pose = floor(bbox_bottom);
    var _pc_pose = floor((bbox_left + bbox_right) * 0.5);
    var _tm_pose = global.tilemap_collision_id;
    var _cap_under_mc = (_tm_pose != noone) && tilemap_cell_thin_floor_near_feet(_tm_pose, _pc_pose, _fy_pose);
    var _center_floor_pose = check_tile_collision(_pc_pose, _fy_pose + GROUND_CHECK_DIST);
    var _pl_pose = floor(bbox_left) + 1;
    var _pr_pose = floor(bbox_right) - 1;
    // Lip landing-crouch / teeter anim are for full-block edges only — shelves use center-missing + toe-hit too, but normal shelf idle/jog is correct there.
    var _shelf_any_near_feet_pose = (_tm_pose != noone) && (
        tilemap_cell_thin_floor_near_feet(_tm_pose, _pl_pose, _fy_pose) ||
        tilemap_cell_thin_floor_near_feet(_tm_pose, _pc_pose, _fy_pose) ||
        tilemap_cell_thin_floor_near_feet(_tm_pose, _pr_pose, _fy_pose));
    if (_shelf_any_near_feet_pose) full_lip_anim_sticky = 0;
    var _fp_pose = _fy_pose + GROUND_CHECK_DIST;
    var _raw_c_teet = check_tile_collision(_pc_pose, _fp_pose);
    var _raw_l_teet = check_tile_collision(_pl_pose, _fp_pose);
    var _raw_r_teet = check_tile_collision(_pr_pose, _fp_pose);
    var _span_teet = 999;
    if (_tm_pose != noone) {
        _span_teet = abs(tilemap_get_cell_x_at_pixel(_tm_pose, _pl_pose, _fy_pose) - tilemap_get_cell_x_at_pixel(_tm_pose, _pr_pose, _fy_pose));
    }
    var _torso_y_pose = floor((bbox_top + bbox_bottom) * 0.5);
    var _torso_overlap_pose = check_tile_collision(_pc_pose, _torso_y_pose);
    var _feet_embed_pose = tilemap_any_feet_row_full_block_embedded(_tm_pose, _pl_pose, _pc_pose, _pr_pose, floor(bbox_left), floor(bbox_right), _fy_pose, FULL_BLOCK_FEET_INTERIOR_LY_MIN);
    // Same geometry as peel/snap skip: center misses at feet probe while a toe still hits — physics grounded can flicker one frame.
    var _teeter_anim = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_shelf_any_near_feet_pose && !_raw_c_teet && (_raw_l_teet || _raw_r_teet) && _span_teet <= CAP_GROUND_CELL_SPAN_MAX
        && wall_side == 0 && abs(vsp) <= 3 && !_torso_overlap_pose && !_feet_embed_pose;
    var _anim_grounded = grounded || _teeter_anim;

    if (!attacking) {
        // Wall visuals always win. Ground/lip logic can flicker for a frame at corners while wall_side is held.
        if (wall_side != 0) {
            sprite_index = spr_mc_walljump;
            image_index = 0;
            image_speed = 0;
            image_xscale = -wall_side * image_base_scale;
        } else if (_anim_grounded) {
            var _hold_full_lip_pose = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_shelf_any_near_feet_pose && (full_lip_anim_sticky > 0 || _teeter_anim)
                && !_feet_embed_pose
                && !is_dashing && sprite_index != spr_mc_dash
                && sprite_index != spr_mc_attack2 && sprite_index != spr_asta_attack1 && sprite_index != spr_mc_walljump;
            if (_hold_full_lip_pose) {
                // No dedicated teeter art yet — keep stable *ground* visuals on full-block lip.
                // If the player is moving, allow jog to play; otherwise idle.
                var _lip_move = (_input_dir != 0) || (abs(hsp) > MOVEMENT_THRESHOLD);
                if (_lip_move) {
                    if (sprite_index != spr_mc_jog) {
                        sprite_index = spr_mc_jog;
                        image_index = 0;
                    }
                } else {
                    if (sprite_index != spr_mc_idle) {
                        sprite_index = spr_mc_idle;
                        image_index = 0;
                    }
                }
                image_speed = 1;
            } else if (sprite_index == spr_mc_jump) {
                // Landing crouch: jump sprite frames ANIM_LAND_CROUCH_START..ANIM_LAND_CROUCH_END
                if (image_index < ANIM_LAND_CROUCH_START) image_index = ANIM_LAND_CROUCH_START;
                image_speed = 1; // Fall anim uses image_speed = 0; restore so crouch can play
                
                if (key_dash && dash_cooldown <= 0 && sprite_index != spr_mc_attack2 && sprite_index != spr_asta_attack1) {
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
            } else if (sprite_index == spr_mc_attack2 || sprite_index == spr_asta_attack1) {
                // Attack just ended — transition to jog/idle
                sprite_index = (abs(hsp) > MOVEMENT_THRESHOLD) ? spr_mc_jog : spr_mc_idle;
                image_index = 0;
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
                image_index = min(1, sprite_get_number(spr_mc_walljump) - 1);
                image_speed = 0;
                image_xscale = last_direction * image_base_scale;
            }
            if (!_on_wall && !_in_wall_extend) {
                var _lip_fall_pose = FULL_BLOCK_EDGE_GROUND_FORGIVE && full_lip_anim_sticky > 0 && !_shelf_any_near_feet_pose
                    && vsp > -2 && vsp < 6 && !_torso_overlap_pose && !_feet_embed_pose;
                if (_lip_fall_pose) {
                    sprite_index = spr_mc_idle;
                    image_index = 0;
                    image_speed = 1;
                } else {
                sprite_index = spr_mc_jump;
                if (vsp < JUMP_RISE_THRESHOLD) {
                // Rising
                image_speed = 1;
                image_index = 0;
            } else if (vsp >= JUMP_PEAK_MIN && vsp <= JUMP_PEAK_MAX) {
                var _fc_pk = floor((bbox_left + bbox_right) * 0.5);
                var _ft_pk = floor(bbox_bottom);
                var _toe_l_pk = floor(bbox_left) + 2;
                var _toe_r_pk = floor(bbox_right) - 2;
                var _pb = _ft_pk + GROUND_CHECK_DIST;
                var _below_any = check_tile_collision(_toe_l_pk, _pb) || check_tile_collision(_fc_pk, _pb) || check_tile_collision(_toe_r_pk, _pb);
                var _near_col = check_tile_collision(_fc_pk, _ft_pk + 1) || check_tile_collision(_fc_pk, _ft_pk + 2)
                    || check_tile_collision(_toe_l_pk, _ft_pk + 1) || check_tile_collision(_toe_r_pk, _ft_pk + 1);
                var _peak_has_floor_center = _below_any && _near_col;
                // Apex-over-ground frame only while still rising. At vsp ≈ 0 on a ledge (tiles 1/5/34/35/36),
                // floor probes stay true and this branch would lock 2f/3f forever; image_speed must be 0 when
                // pinning frame 2 or GM advances to subimage 3 the same frame.
                if (_peak_has_floor_center && vsp < 0) {
                    image_speed = 0;
                    image_index = 2;
                } else if (_peak_has_floor_center && vsp <= 0) {
                    image_speed = 0;
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= ANIM_HAIR_FLICKER_INTERVAL) hair_flicker_counter = 0;
                    image_index = (hair_flicker_counter < ANIM_HAIR_FLICKER_THRESHOLD) ? 5 : 6;
                } else {
                    image_speed = 0;
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= ANIM_HAIR_FLICKER_INTERVAL) hair_flicker_counter = 0;
                    image_index = (hair_flicker_counter < ANIM_HAIR_FLICKER_THRESHOLD) ? 5 : 6;
                }
            } else {
                // Falling (vsp > 1): early landing crouch only when ground is almost straight below feet center
                // (origin-based probe was false-positive beside one-way ledges).
                var _ft_anim = floor(bbox_bottom);
                var _fc_anim = floor((bbox_left + bbox_right) * 0.5);
                var _toe_l_am = floor(bbox_left) + 2;
                var _toe_r_am = floor(bbox_right) - 2;
                var _probe_deep = _ft_anim + LANDING_ANIM_DIST;
                var _pd = _probe_deep;
                var _below_anim = check_tile_collision(_toe_l_am, _pd) || check_tile_collision(_fc_anim, _pd) || check_tile_collision(_toe_r_am, _pd);
                var _near_anim = check_tile_collision(_fc_anim, _ft_anim + 1) || check_tile_collision(_fc_anim, _ft_anim + 2)
                    || check_tile_collision(_toe_l_am, _ft_anim + 1) || check_tile_collision(_toe_r_am, _ft_anim + 1);
                var _is_near_ground = (vsp > 0) && _below_anim && _near_anim;
                
                if (_is_near_ground) {
                    image_speed = 1;
                    image_index = ANIM_LAND_CROUCH_START; // Landing imminent: show crouch early
                } else {
                    image_speed = 0;
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= ANIM_HAIR_FLICKER_INTERVAL) hair_flicker_counter = 0;
                    image_index = (hair_flicker_counter < ANIM_HAIR_FLICKER_THRESHOLD) ? 5 : 6;
                }
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
        image_xscale = -wall_side * image_base_scale;
        last_direction = wall_side;
    } else if (_input_dir != 0 && stunTimer <= 0 && !attacking) {
        image_xscale = (_input_dir > 0) ? image_base_scale : -image_base_scale;
        last_direction = _input_dir;
    } else if (attacking && stunTimer <= 0) {
        if (last_direction != 0) image_xscale = last_direction * image_base_scale;
    }

    // --- 8b. FEET FLUSH AFTER ANIM / FACING ---
    // Full-block lip: center foot probe often misses while toes are on tile — flush y+=1 fights lip forgiveness and shakes the actor.
    // Skip flush whenever center misses floor on a full block (teeter) — not only when sticky already refilled.
    var _full_block_teeter_skip_8b = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap_under_mc && !_center_floor_pose;
    if (global.tilemap_collision_id != noone && grounded && vsp == 0 && wall_side == 0 && !attacking
        && !_full_block_teeter_skip_8b && !(FULL_BLOCK_EDGE_GROUND_FORGIVE && full_lip_anim_sticky > 0)) {
        feet_y = floor(bbox_bottom);
        var _pl0b = floor(bbox_left) + 1;
        var _pr0b = floor(bbox_right) - 1;
        var _pc0b = floor((bbox_left + bbox_right) * 0.5);
        var _thin_snap_8b = (_tm_lc != noone) && (
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pc0b, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pl0b, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_lc, _pr0b, feet_y));
        var _snap_budget_8b = _thin_snap_8b ? GROUND_SNAP_POST_THIN_CAP_MAX : GROUND_SNAP_POST_ANIM_MAX;
        repeat (GROUND_SNAP_POST_ANIM_MAX) {
            if (_snap_budget_8b <= 0) break;
            feet_y = floor(bbox_bottom);
            var _pl_f = floor(bbox_left) + 1;
            var _pr_f = floor(bbox_right) - 1;
            var _pc_f = floor((bbox_left + bbox_right) * 0.5);
            var _fc_f = check_tile_collision(_pc_f, feet_y);
            var _fl_f = check_tile_collision(_pl_f, feet_y);
            var _fr_f = check_tile_collision(_pr_f, feet_y);
            if (_fc_f || _fl_f || _fr_f) break;
            var _u1_fc = check_tile_collision(_pc_f, feet_y + GROUND_CHECK_DIST);
            var _u1_fl = check_tile_collision(_pl_f, feet_y + GROUND_CHECK_DIST);
            var _u1_fr = check_tile_collision(_pr_f, feet_y + GROUND_CHECK_DIST);
            if (_u1_fc || _u1_fl || _u1_fr) {
                y += 1;
                _snap_budget_8b--;
                continue;
            }
            var _below_f = false;
            for (var _df = 2; _df <= GROUND_SNAP_PROBE_DEPTH; _df++) {
                if (check_tile_collision(_pc_f, feet_y + _df) ||
                    check_tile_collision(_pl_f, feet_y + _df) ||
                    check_tile_collision(_pr_f, feet_y + _df)) {
                    _below_f = true;
                    break;
                }
            }
            if (!_below_f) break;
            y += 1;
            _snap_budget_8b--;
        }
    }
    
    if (post_attack_accel_timer > 0) post_attack_accel_timer--;
    if (grounded) side_entry_airborne_frames = 0;
    else side_entry_airborne_frames = min(side_entry_airborne_frames + 1, 300);
    shelf_bb_bottom_prev = bbox_bottom;
}