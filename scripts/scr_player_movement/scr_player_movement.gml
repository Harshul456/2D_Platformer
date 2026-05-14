/// @function scr_player_movement
/// @description Main player movement: input, grounded/coyote, jump, gravity/dash,
///             horizontal/vertical collision, 6c grounded re-check, animation, direction.
///             All tunable numbers live in obj_player Create (no magic numbers here).
function scr_player_movement() {
    
    // --- 0. INITIALIZATION ---
    if (is_dying) { vsp += grv; y += vsp; return; }
    shelf_threshold_snap_this_step = false;
    global.player_ledge_bb_prev = shelf_bb_bottom_prev;
    global.player_move_vsp = vsp;

    if (DEBUG_LEDGE_AIR_STALL && !debug_ledge_hunt_announced) {
        debug_ledge_hunt_announced = true;
        show_debug_message("LEDGE_DBG: hunt on — show_debug_message only appears when you Run from the IDE (not from a built .exe). Yellow HUD still works in builds.");
    }
    
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

        // Jump buffer (decay after §2c — can pause while sliding into wall with a live jump buffer, or hugging wall with air jump banked)
        if (key_jump) jump_buffer_timer = jump_buffer_max;
        
        // Attack buffer: only while idle (refilling during swing); chain buffer for 1→2 on new press during swing 1
        if (key_attack) {
            if (!attacking) attack_buffer_timer = attack_buffer_max;
            else if (attacking && comboCount == 1) attack_chain_buffer_timer = attack_chain_buffer_max;
        }
        if (!attacking && attack_buffer_timer > 0) attack_buffer_timer--;
        if (attack_chain_buffer_timer > 0) attack_chain_buffer_timer--;
    }

    // --- 2. GROUNDED & COYOTE LOGIC ---
    var _s2_grounded_in = grounded;
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
    // Bbox corners + feet row: at the last pixel of a full tile, inset feet+1 probes can all miss one frame while the
    // collision hull still overlaps the top surface — use these only for lip fence / bless / debounce (not core votes).
    var _bl_s2 = floor(bbox_left);
    var _br_s2 = floor(bbox_right);
    var _floor_probe_broad = touch_floor_any
        || check_tile_collision(_bl_s2, _floor_probe_y)
        || check_tile_collision(_br_s2, _floor_probe_y);
    var _feet_row_support = check_tile_collision(p_center, feet_y) || check_tile_collision(p_left, feet_y) || check_tile_collision(p_right, feet_y)
        || check_tile_collision(_bl_s2, feet_y) || check_tile_collision(_br_s2, feet_y);
    var _raw_support_n = (touch_floor_center ? 1 : 0) +
        (check_tile_collision(p_left,  _floor_probe_y) ? 1 : 0) +
        (check_tile_collision(p_right, _floor_probe_y) ? 1 : 0);
    // True feet under bbox L/R — center alone can hit a vertical wall beside the ledge while "floating".
    var _toe_floor_raw = check_tile_collision(p_left, _floor_probe_y) || check_tile_collision(p_right, _floor_probe_y);
    // Inset-only floor hits (no toe / no double support) = hanging off ledge — not supported ground on full blocks.
    var touch_floor_for_ground = touch_floor_any && (_feet_on_cap_cell || _raw_support_n >= 2 || (_raw_support_n >= 1 && _toe_floor_raw));
    var touch_floor_majority = (_raw_support_n >= GROUND_LAND_VOTES_MIN_AIR);
    var _stand_l = check_floor_standable(_xl_floor, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_c = check_floor_standable(p_center, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var _stand_r = check_floor_standable(_xr_floor, feet_y, GROUND_CHECK_DIST, GROUND_STANDABLE_EMBED_PX);
    var touch_stand_majority = ((_stand_l ? 1 : 0) + (_stand_c ? 1 : 0) + (_stand_r ? 1 : 0) >= GROUND_LAND_VOTES_MIN_AIR);
    // Strict vote logic blocks relaxed lip grounding; cap geometry already prevents standing past the art.
    var _strict3426_ground = _shelf_strict_34_36 && _shelf_cap_feet_s2
        && touch_floor_for_ground && (_stand_l || _stand_c || _stand_r) && abs(vsp) <= SHELF_STAND_VSP_ABS_MAX;
    // One toe on a narrow shelf: allowed except on indices 34/36 (no relaxed hang past lip). Tile 1 uses tighter |vsp|.
    var _vsp_toler = SHELF_STAND_VSP_ABS_MAX;
    if (_shelf_touch_tile1) _vsp_toler = min(_vsp_toler, SHELF_STAND_VSP_TILE1);
    var touch_stand_for_ground = (touch_stand_majority && (_feet_on_cap_cell || touch_floor_for_ground))
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
        if (!_touch_floor_anchor && touch_stand_for_ground && touch_floor_for_ground) {
            var _sx_la = tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y);
            var _sx_ra = tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y);
            if (abs(_sx_la - _sx_ra) <= CAP_GROUND_CELL_SPAN_MAX) _touch_floor_anchor = true;
        }
    }
    // Full blocks: allow anchor when center misses void but inset stand votes + feet span say "on one platform" (lip stand).
    if (!_touch_floor_anchor && !_feet_on_cap_cell && FULL_BLOCK_EDGE_GROUND_FORGIVE && _tm_lc != noone
        && touch_stand_for_ground && touch_floor_for_ground) {
        var _s2_span = abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y));
        if (_s2_span <= CAP_GROUND_CELL_SPAN_MAX) _touch_floor_anchor = true;
    }
    var _coyote_floor_refresh = !((jump_count >= 2) && (!grounded));
    var _thin_cap_ground = _feet_on_cap_cell && (_stand_l || _stand_c || _stand_r) && touch_floor_any && _touch_floor_anchor
        && vsp >= -4;
    
    var _span_feet_s2gv = (_tm_lc != noone) ? abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y)) : 999;
    var _shelf_ground_vote_ok = (_raw_support_n >= GROUND_LAND_VOTES_MIN_AIR)
        || (FULL_BLOCK_EDGE_GROUND_FORGIVE && !_feet_on_cap_cell && touch_floor_for_ground && _raw_support_n >= 1
            && _span_feet_s2gv <= CAP_GROUND_CELL_SPAN_MAX && touch_stand_majority)
        || (!_shelf_strict_34_36 && _feet_on_cap_cell && touch_floor_any && abs(tilemap_get_cell_x_at_pixel(_tm_lc, p_left, feet_y) - tilemap_get_cell_x_at_pixel(_tm_lc, p_right, feet_y)) <= CAP_GROUND_CELL_SPAN_MAX);
    // Full-block lip: §2 floor/stand votes can flicker off one frame while toes/sticky still say "on tile". Hold coyote
    // while _s2_lip_fence; if we already cleared grounded, restore same frame (otherwise gravity + motion desync §6c).
    var _lip_ctx_wide = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_feet_on_cap_cell && abs(vsp) <= 2.5
        && (_span_feet_s2gv <= CAP_GROUND_CELL_SPAN_MAX || full_lip_anim_sticky > 0);
    if (_lip_ctx_wide) {
        if (_floor_probe_broad || _feet_row_support || touch_floor_any) lip_s2_edge_air_streak = 0;
        else lip_s2_edge_air_streak = min(lip_s2_edge_air_streak + 1, 10);
    } else {
        lip_s2_edge_air_streak = 0;
    }
    var _s2_lip_geom_side = (_raw_support_n >= 1 && _toe_floor_raw && !touch_floor_center);
    var _s2_lip_fence = _lip_ctx_wide
        && ((touch_floor_for_ground && (full_lip_anim_sticky > 0 || _s2_lip_geom_side))
            || (full_lip_anim_sticky > 0 && _raw_support_n >= 1 && _toe_floor_raw)
            || (full_lip_anim_sticky > 0 && _feet_row_support));
    var _s2_lip_hold = _s2_grounded_in && _s2_lip_fence;
    if ((touch_stand_for_ground && _shelf_ground_vote_ok && _touch_floor_anchor) || _thin_cap_ground || _strict3426_ground) {
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        air_chain_jump_used = false;
    } else {
        if (_s2_lip_hold) {
            coyote_time_timer = coyote_time_max;
        } else {
            if (touch_floor_for_ground && _coyote_floor_refresh) coyote_time_timer = coyote_time_max;
            if (coyote_time_timer > 0) coyote_time_timer--;
            else if (!(_lip_ctx_wide && lip_s2_edge_air_streak < GROUND_LIP_S2_AIR_STREAK_TO_CLEAR)) grounded = false;
        }
        if (!_s2_lip_hold && (!touch_stand_for_ground || !_shelf_ground_vote_ok || !_touch_floor_anchor)
            && !(_feet_on_cap_cell && _touch_floor_anchor && touch_floor_for_ground && (_stand_l || _stand_c || _stand_r))) {
            if (!(_lip_ctx_wide && lip_s2_edge_air_streak < GROUND_LIP_S2_AIR_STREAK_TO_CLEAR)) grounded = false;
        }
    }
    if (!grounded && _s2_grounded_in && _s2_lip_fence) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
    } else if (!grounded && lip_ground_bless > 0 && _lip_ctx_wide && (_floor_probe_broad || _feet_row_support)) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
    } else if (!grounded && lip_ground_bless > 0) {
        lip_ground_bless--;
    }
    if (grounded && _lip_ctx_wide) lip_ground_bless = GROUND_LIP_GROUND_BLESS_MAX;

    // --- 2b. WALL CONTACT (mask-edge column + 3 heights — rejects “feet-only” / above-ledge false walls) ---
    wall_side = 0;
    if (!grounded && global.tilemap_collision_id != noone) {
        var __ft_w = feet_y;
        var __hd_w = head_y;
        var __cy_w = center_y;
        var _w_hold = (stunTimer <= 0) ? (key_right - key_left) : 0;
        var _bwl = (variable_instance_exists(id, "WALL_CONTACT_HOLD_BIAS_PX") ? WALL_CONTACT_HOLD_BIAS_PX : 3);
        var __wxl_w = floor(bbox_left) - WALL_FACE_PROBE_OUTSET + ((_w_hold < 0) ? -_bwl : 0);
        var __wxr_w = floor(bbox_right) + WALL_FACE_PROBE_OUTSET + ((_w_hold > 0) ? _bwl : 0);
        var __ylo_w = __ft_w - 1;
        var __ymid_w = __cy_w;
        var __yhi_w = clamp(__hd_w + WALL_BODY_HI_FROM_HEAD, __hd_w + 2, __ft_w - 4);
        var __l1 = check_tile_collision(__wxl_w, __ylo_w);
        var __l2 = check_tile_collision(__wxl_w, __ymid_w);
        var __l3 = check_tile_collision(__wxl_w, __yhi_w);
        var __r1 = check_tile_collision(__wxr_w, __ylo_w);
        var __r2 = check_tile_collision(__wxr_w, __ymid_w);
        var __r3 = check_tile_collision(__wxr_w, __yhi_w);
        var __ln = (__l1 ? 1 : 0) + (__l2 ? 1 : 0) + (__l3 ? 1 : 0);
        var __rn = (__r1 ? 1 : 0) + (__r2 ? 1 : 0) + (__r3 ? 1 : 0);
        var _wl = (__ln >= WALL_CONTACT_MIN_SAMPLES);
        var _wr = (__rn >= WALL_CONTACT_MIN_SAMPLES);
        if (wall_kick_cooldown > 0) {
            if (wall_kick_from_side == -1) _wl = false;
            if (wall_kick_from_side == 1) _wr = false;
        }
        if (_wl && !_wr) wall_side = -1;
        else if (_wr && !_wl) wall_side = 1;
        else if (_wl && _wr) {
            var _wdir = key_right - key_left;
            if (_wdir < 0) wall_side = -1;
            else if (_wdir > 0) wall_side = 1;
            else if (sign(hsp) != 0) wall_side = sign(hsp);
            else wall_side = -sign(last_direction);
        }
    }

    // --- 2c. WALL-JUMP DEFER SCAN (§3 runs before horizontal; wall_side can be 0 until we scrape the wall) ---
    var _wall_jump_defer = false;
    if (!grounded && global.tilemap_collision_id != noone && wall_side == 0 && jump_buffer_timer > 0 && stunTimer <= 0) {
        var _hug_de = key_right - key_left;
        var _head_de = !check_tile_collision(p_center, head_y - WALL_JUMP_CEIL_CLEAR, true, feet_y);
        if (_hug_de != 0 && _head_de) {
            var _prox_n = (variable_instance_exists(id, "WALL_JUMP_PROXIMITY_PX") ? WALL_JUMP_PROXIMITY_PX : 6);
            var _sx_de = (_hug_de > 0) ? (floor(bbox_right) + 1) : (floor(bbox_left) - 1);
            var _yM_de = floor((bbox_top + bbox_bottom) * 0.5);
            var _yF_de = feet_y - 8;
            for (var _ide = 1; _ide <= _prox_n; _ide++) {
                var _qx_de = _sx_de + _hug_de * _ide;
                if (check_tile_collision(_qx_de, _yM_de) || check_tile_collision(_qx_de, _yF_de)) {
                    _wall_jump_defer = true;
                    break;
                }
            }
        }
    }

    if (stunTimer <= 0 && jump_buffer_timer > 0) {
        var _pause_jump_buf = false;
        if (!grounded) {
            if (_wall_jump_defer) {
                _pause_jump_buf = true;
            } else if (wall_side != 0) {
                var _hug_buf = key_right - key_left;
                if (_hug_buf == wall_side && air_chain_jump_used) {
                    _pause_jump_buf = true;
                } else if (_hug_buf == wall_side && vsp > 0 && jump_buffer_timer > 0) {
                    // Sliding into wall with an unconsumed jump buffer — don't burn frames before the jump press (late wall jump).
                    _pause_jump_buf = true;
                }
            }
        }
        if (!_pause_jump_buf) jump_buffer_timer--;
    }

    // --- 3. JUMP TRIGGER (wall jump > ground / air jump) ---
    var jumped_this_frame = false;
    if (stunTimer <= 0 && jump_buffer_timer > 0 && !attacking) {
        var _head_room_ok = !check_tile_collision(p_center, head_y - WALL_JUMP_CEIL_CLEAR, true, feet_y);
        // Wall kick only while falling into the slide (vsp>0); rising + second jump = double jump, not kick off wall.
        var _wj_fall_ok = vsp > WALL_JUMP_MIN_FALL_VSP;
        if (!grounded && wall_side != 0 && _head_room_ok && _wj_fall_ok && ((key_right - key_left) == wall_side) && !air_chain_jump_used) {
            wall_kick_from_side = wall_side;
            wall_kick_cooldown = WALL_KICK_COOLDOWN_FRAMES;
            vsp = -WALL_JUMP_VSP;
            hsp = -wall_side * WALL_JUMP_HSP;
            runMomentum = hsp;
            last_direction = -wall_side;
            jump_buffer_timer = 0;
            jumped_this_frame = true;
            jump_count = 0;
            air_chain_jump_used = false;
            coyote_time_timer = 0;
            grounded = false;
            lip_ground_bless = 0;
            lip_s2_edge_air_streak = 0;
            wall_jump_lock = WALL_JUMP_LOCK_FRAMES;
            wall_jump_extend_timer = WALL_JUMP_EXTEND_FRAMES;
            wall_jump_kick_hold_timer = WALL_JUMP_KICK_HOLD_FRAMES;
            is_dashing = false;
        } else if (!_wall_jump_defer && (coyote_time_timer > 0 || jump_count < 2)) {
            var _jump_from_grounded = grounded;
            vsp = -jumpsp;
            jump_count++;
            coyote_time_timer = 0;
            jump_buffer_timer = 0;
            grounded = false;
            lip_ground_bless = 0;
            lip_s2_edge_air_streak = 0;
            jumped_this_frame = true;
            if (!_jump_from_grounded && jump_count >= 2) {
                air_chain_jump_used = true;
            }
            
            if (is_dashing || abs(hsp) > walksp) {
                runMomentum = hsp;
                is_dashing = false;
            }
        }
    }

    // §5b wall-jump must use this (pre-gravity-after-§3), not post-§4 vsp — one grv tick can flip a tiny rise
    // into "falling" and steal a buffered double jump after defer / late wall contact (often asymmetric L vs R).
    var _vsp_wall_jump_fall_ref = vsp;

    // --- 4. GRAVITY & DASH LOGIC ---
    vsp += grv;
    // Short-hop: release jump early caps rise speed (jump_cut_multiplier)
    if (vsp < 0 && !key_jump_held) vsp = max(vsp, jumpsp * (-jump_cut_multiplier));
    // Wall slide: MMX wall_slide only while falling — don’t cling on rise past a ledge
    if (!grounded && wall_side != 0 && stunTimer <= 0 && vsp > 0) {
        var _wslide_in = (key_right - key_left);
        if (_wslide_in == wall_side && vsp > WALL_SLIDE_VSP) vsp = WALL_SLIDE_VSP;
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
            if (grounded && !jumped_this_frame) {
                var _walk_scale = 1;
                if (post_attack_accel_timer > 0) {
                    _walk_scale = 1 - post_attack_accel_timer / POST_ATTACK_ACCEL_FRAMES;
                    if (_walk_scale < 0.35) _walk_scale = 0.35;
                }
                hsp = walksp * inputDir * _walk_scale;
                runMomentum = 0;
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

    // After air control: wall-kick frames enforce separation (MMX wall_jump move_x away while holding toward wall)
    if (!grounded && wall_kick_cooldown > 0 && stunTimer <= 0) {
        var _awm = -wall_kick_from_side;
        var _mna = min(max(WALL_JUMP_HSP * WALL_JUMP_AWAY_CLAMP_MULT, WALL_JUMP_MIN_AWAY_HOLD), WALL_JUMP_HSP);
        if (_awm < 0) hsp = min(hsp, -_mna);
        else hsp = max(hsp, _mna);
        runMomentum = hsp;
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
            var _ledge_mount = tilemap_horizontal_ledge_mount_priority(_tm_h, _wx, _bb_bot_h, min(_y_h, center_y, _y_t), max(_y_h, center_y, _y_t), HORIZONTAL_LEDGE_WINDOW_PX);
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

    // Re-sample wall contact after horizontal resolve (position changed this step).
    wall_side = 0;
    if (!grounded && global.tilemap_collision_id != noone) {
        feet_y = floor(bbox_bottom);
        head_y = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        var __ft_rb = feet_y;
        var __hd_rb = head_y;
        var __cy_rb = center_y;
        var _w_hold_rb = (stunTimer <= 0) ? (key_right - key_left) : 0;
        var _bwl_rb = (variable_instance_exists(id, "WALL_CONTACT_HOLD_BIAS_PX") ? WALL_CONTACT_HOLD_BIAS_PX : 3);
        var __wxl_rb = floor(bbox_left) - WALL_FACE_PROBE_OUTSET + ((_w_hold_rb < 0) ? -_bwl_rb : 0);
        var __wxr_rb = floor(bbox_right) + WALL_FACE_PROBE_OUTSET + ((_w_hold_rb > 0) ? _bwl_rb : 0);
        var __ylo_rb = __ft_rb - 1;
        var __ymid_rb = __cy_rb;
        var __yhi_rb = clamp(__hd_rb + WALL_BODY_HI_FROM_HEAD, __hd_rb + 2, __ft_rb - 4);
        var __l1b = check_tile_collision(__wxl_rb, __ylo_rb);
        var __l2b = check_tile_collision(__wxl_rb, __ymid_rb);
        var __l3b = check_tile_collision(__wxl_rb, __yhi_rb);
        var __r1b = check_tile_collision(__wxr_rb, __ylo_rb);
        var __r2b = check_tile_collision(__wxr_rb, __ymid_rb);
        var __r3b = check_tile_collision(__wxr_rb, __yhi_rb);
        var __lnb = (__l1b ? 1 : 0) + (__l2b ? 1 : 0) + (__l3b ? 1 : 0);
        var __rnb = (__r1b ? 1 : 0) + (__r2b ? 1 : 0) + (__r3b ? 1 : 0);
        var _wl_rb = (__lnb >= WALL_CONTACT_MIN_SAMPLES);
        var _wr_rb = (__rnb >= WALL_CONTACT_MIN_SAMPLES);
        if (wall_kick_cooldown > 0) {
            if (wall_kick_from_side == -1) _wl_rb = false;
            if (wall_kick_from_side == 1) _wr_rb = false;
        }
        if (_wl_rb && !_wr_rb) wall_side = -1;
        else if (_wr_rb && !_wl_rb) wall_side = 1;
        else if (_wl_rb && _wr_rb) {
            var _wdir2 = key_right - key_left;
            if (_wdir2 < 0) wall_side = -1;
            else if (_wdir2 > 0) wall_side = 1;
            else if (sign(hsp) != 0) wall_side = sign(hsp);
            else wall_side = -sign(last_direction);
        }
    }

    // --- 5b-post. WALL JUMP (second chance: §3 runs before horizontal; wall_side can become valid after scrape) ---
    if (!jumped_this_frame && stunTimer <= 0 && jump_buffer_timer > 0 && !attacking) {
        feet_y = floor(bbox_bottom);
        head_y = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        p_left = floor(bbox_left) + 1;
        p_right = floor(bbox_right) - 1;
        p_center = floor((bbox_left + bbox_right) * 0.5);
        var _head_post = !check_tile_collision(p_center, head_y - WALL_JUMP_CEIL_CLEAR, true, feet_y);
        var _hug_post = key_right - key_left;
        var _wj_post_fall_ok = _vsp_wall_jump_fall_ref > WALL_JUMP_MIN_FALL_VSP;
        if (!grounded && wall_side != 0 && _head_post && _wj_post_fall_ok && (_hug_post == wall_side) && !air_chain_jump_used) {
            wall_kick_from_side = wall_side;
            wall_kick_cooldown = WALL_KICK_COOLDOWN_FRAMES;
            // Match §3 early wall jump after one gravity tick: vsp was already += grv in §4 this frame.
            vsp = -WALL_JUMP_VSP + grv;
            hsp = -wall_side * WALL_JUMP_HSP;
            runMomentum = hsp;
            last_direction = -wall_side;
            jump_buffer_timer = 0;
            jumped_this_frame = true;
            jump_count = 0;
            air_chain_jump_used = false;
            coyote_time_timer = 0;
            grounded = false;
            lip_ground_bless = 0;
            lip_s2_edge_air_streak = 0;
            wall_jump_lock = WALL_JUMP_LOCK_FRAMES;
            wall_jump_extend_timer = WALL_JUMP_EXTEND_FRAMES;
            wall_jump_kick_hold_timer = WALL_JUMP_KICK_HOLD_FRAMES;
            is_dashing = false;
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
    var _y_pre_vertical = y;
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
        air_chain_jump_used = false;
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
                        // Strict: all three (inset L, center, inset R) must be clear to move down 1px.
                        // If both inset columns are already air at the step row but center still hits, allow (lip / hull lag).
                        var _fall_inset = (variable_instance_exists(id, "AIR_FALL_EDGE_INSET") ? AIR_FALL_EDGE_INSET : GROUND_PROBE_EDGE_INSET);
                        _fall_inset = max(_fall_inset, GROUND_PROBE_EDGE_INSET);
                        var _pl_fall = floor(bbox_left) + _fall_inset;
                        var _pr_fall = floor(bbox_right) - _fall_inset;
                        if (_pl_fall >= _pr_fall) {
                            _pl_fall = p_left;
                            _pr_fall = p_right;
                        }
                        var _hil = check_tile_collision(_pl_fall, _foot_probe_y, false, noone, true);
                        var _hir = check_tile_collision(_pr_fall, _foot_probe_y, false, noone, true);
                        var _hic = check_tile_collision(p_center, _foot_probe_y, false, noone, true);
                        _col_clear = !_hil && !_hic && !_hir;
                        if (!_col_clear && !_hil && !_hir) {
                            _col_clear = true;
                        }
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
                        air_chain_jump_used = false;
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
        if (grounded && vsp > 0.001 && stunTimer <= 0) vsp = 0;
    } else if (!grounded && global.tilemap_collision_id != noone && stunTimer <= 0 && abs(vsp) <= 0.001) {
        // When vsp is exactly 0, the stepped §6 loop above is skipped (apex, friction, collision wipe). In air
        // we still need one downward resolution pass or gravity seed — otherwise ledge separation can sit motionless
        // until vsp becomes non-zero (intermittent hover + sudden fall).
        feet_y = floor(bbox_bottom);
        head_y = floor(bbox_top);
        center_y = floor((bbox_top + bbox_bottom) * 0.5);
        p_left = floor(bbox_left) + 1;
        p_right = floor(bbox_right) - 1;
        p_center = floor((bbox_left + bbox_right) * 0.5);
        var _foot_probe_z = feet_y + 1;
        var _tmvz = global.tilemap_collision_id;
        var _col_clear_z;
        var _shelf_support_z = (_tmvz != noone) && tilemap_shelf_cap_near_feet(_tmvz, p_left, p_center, p_right, feet_y);
        if (_shelf_support_z) {
            _col_clear_z = !check_tile_collision(p_left, feet_y + 1, false, noone, false) &&
                !check_tile_collision(p_center, feet_y + 1, false, noone, false) &&
                !check_tile_collision(p_right, feet_y + 1, false, noone, false);
        } else {
            var _thin_row_z = (_tmvz != noone) && (
                tilemap_cell_thin_floor_tile(_tmvz, p_left, _foot_probe_z) ||
                tilemap_cell_thin_floor_tile(_tmvz, p_center, _foot_probe_z) ||
                tilemap_cell_thin_floor_tile(_tmvz, p_right, _foot_probe_z));
            if (_thin_row_z) {
                _col_clear_z = !check_tile_collision(p_left, _foot_probe_z, false, noone, true) &&
                    !check_tile_collision(p_center, _foot_probe_z, false, noone, true) &&
                    !check_tile_collision(p_right, _foot_probe_z, false, noone, true);
            } else {
                var _fall_inset_z = max(variable_instance_exists(id, "AIR_FALL_EDGE_INSET") ? AIR_FALL_EDGE_INSET : GROUND_PROBE_EDGE_INSET, GROUND_PROBE_EDGE_INSET);
                var _pl_fz = floor(bbox_left) + _fall_inset_z;
                var _pr_fz = floor(bbox_right) - _fall_inset_z;
                if (_pl_fz >= _pr_fz) {
                    _pl_fz = p_left;
                    _pr_fz = p_right;
                }
                var _hilz = check_tile_collision(_pl_fz, _foot_probe_z, false, noone, true);
                var _hirz = check_tile_collision(_pr_fz, _foot_probe_z, false, noone, true);
                var _hicz = check_tile_collision(p_center, _foot_probe_z, false, noone, true);
                _col_clear_z = !_hilz && !_hicz && !_hirz;
                if (!_col_clear_z && !_hilz && !_hirz) {
                    _col_clear_z = true;
                }
            }
        }
        var _feet_row_touch_z = check_tile_collision(p_center, feet_y) || check_tile_collision(p_left, feet_y) || check_tile_collision(p_right, feet_y);
        if (_col_clear_z && _feet_row_touch_z) {
            y += 1;
            feet_y = floor(bbox_bottom);
            head_y = floor(bbox_top);
            center_y = floor((bbox_top + bbox_bottom) * 0.5);
            p_left = floor(bbox_left) + 1;
            p_right = floor(bbox_right) - 1;
            p_center = floor((bbox_left + bbox_right) * 0.5);
        } else {
            // Blocked lip, open air at exact-zero vsp, or 1px hover with no feet-row hull sample — still need fall
            // progress; §6d peel is vsp-gated and this branch only runs when the stepped loop was skipped.
            vsp = grv;
        }
    }

    // --- 6x. AIR LIP UNSTICK (after vertical, before peel) ---
    // When !grounded and |vsp|≈0, §6d peel does not run. Nudge down + seed grv only when floor helpers disagree
    // with §2 (!_tffg_u) and the inset row at feet+1 is not fully solid (original behavior — avoids teeter jitter).
    if (!grounded && global.tilemap_collision_id != noone && abs(vsp) <= 0.001 && stunTimer <= 0) {
        feet_y = floor(bbox_bottom);
        var _tm_u = global.tilemap_collision_id;
        var _pLu = floor(bbox_left) + 1;
        var _pRu = floor(bbox_right) - 1;
        var _pCu = floor((bbox_left + bbox_right) * 0.5);
        var _pGlu = floor(bbox_left) + GROUND_PROBE_EDGE_INSET;
        var _pGru = floor(bbox_right) - GROUND_PROBE_EDGE_INSET;
        if (_pGlu >= _pGru) {
            _pGlu = _pLu;
            _pGru = _pRu;
        }
        var _fpy_u = feet_y + GROUND_CHECK_DIST;
        var _cap_u = (_tm_u != noone) && (
            tilemap_cell_thin_floor_near_feet(_tm_u, _pCu, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_u, _pLu, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_u, _pRu, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_u, _pGlu, feet_y) ||
            tilemap_cell_thin_floor_near_feet(_tm_u, _pGru, feet_y));
        var _xlf_u = _cap_u ? _pLu : _pGlu;
        var _xrf_u = _cap_u ? _pRu : _pGru;
        var _tf_any_u = check_tile_collision(_pCu, _fpy_u) || check_tile_collision(_xlf_u, _fpy_u) || check_tile_collision(_xrf_u, _fpy_u);
        var _rn_u = (check_tile_collision(_pCu, _fpy_u) ? 1 : 0) +
            (check_tile_collision(_pLu, _fpy_u) ? 1 : 0) +
            (check_tile_collision(_pRu, _fpy_u) ? 1 : 0);
        var _toe_u = check_tile_collision(_pLu, _fpy_u) || check_tile_collision(_pRu, _fpy_u);
        var _tffg_u = _tf_any_u && (_cap_u || _rn_u >= 2 || (_rn_u >= 1 && _toe_u));
        if (!_tffg_u && _tf_any_u) {
            var _fi_u = max(variable_instance_exists(id, "AIR_FALL_EDGE_INSET") ? AIR_FALL_EDGE_INSET : GROUND_PROBE_EDGE_INSET, GROUND_PROBE_EDGE_INSET);
            var _pl_u = floor(bbox_left) + _fi_u;
            var _pr_u = floor(bbox_right) - _fi_u;
            if (_pl_u >= _pr_u) {
                _pl_u = _pLu;
                _pr_u = _pRu;
            }
            var _py_u = feet_y + 1;
            var _Lu_u = check_tile_collision(_pl_u, _py_u, false, noone, true);
            var _Ru_u = check_tile_collision(_pr_u, _py_u, false, noone, true);
            var _Cu_u = check_tile_collision(_pCu, _py_u, false, noone, true);
            if (!(_Lu_u && _Ru_u && _Cu_u)) {
                y += 1;
                vsp = grv;
            }
        }
    }

    // --- 6x2. AIR: DOWN BLOCKED -> SEED GRAVITY (opens §6d peel same frame when vertical cleared all vsp) ---
    // Apex-safe: only when a 1px air-down step is blocked (same rules as §6 falling). Not when open air is below.
    if (!grounded && global.tilemap_collision_id != noone && abs(vsp) <= 0.001 && stunTimer <= 0) {
        feet_y = floor(bbox_bottom);
        var _pl_db = floor(bbox_left) + 1;
        var _pr_db = floor(bbox_right) - 1;
        var _pc_db = floor((bbox_left + bbox_right) * 0.5);
        var _tm_db = global.tilemap_collision_id;
        var _fp_db = feet_y + 1;
        var _clear_db;
        var _shelf_db = (_tm_db != noone) && tilemap_shelf_cap_near_feet(_tm_db, _pl_db, _pc_db, _pr_db, feet_y);
        if (_shelf_db) {
            _clear_db = !check_tile_collision(_pl_db, feet_y + 1, false, noone, false)
                && !check_tile_collision(_pc_db, feet_y + 1, false, noone, false)
                && !check_tile_collision(_pr_db, feet_y + 1, false, noone, false);
        } else {
            var _thin_db = (_tm_db != noone) && (
                tilemap_cell_thin_floor_tile(_tm_db, _pl_db, _fp_db) ||
                tilemap_cell_thin_floor_tile(_tm_db, _pc_db, _fp_db) ||
                tilemap_cell_thin_floor_tile(_tm_db, _pr_db, _fp_db));
            if (_thin_db) {
                _clear_db = !check_tile_collision(_pl_db, _fp_db, false, noone, true)
                    && !check_tile_collision(_pc_db, _fp_db, false, noone, true)
                    && !check_tile_collision(_pr_db, _fp_db, false, noone, true);
            } else {
                var _fi_db = max(variable_instance_exists(id, "AIR_FALL_EDGE_INSET") ? AIR_FALL_EDGE_INSET : GROUND_PROBE_EDGE_INSET, GROUND_PROBE_EDGE_INSET);
                var _plf_db = floor(bbox_left) + _fi_db;
                var _prf_db = floor(bbox_right) - _fi_db;
                if (_plf_db >= _prf_db) {
                    _plf_db = _pl_db;
                    _prf_db = _pr_db;
                }
                var _hil_db = check_tile_collision(_plf_db, _fp_db, false, noone, true);
                var _hir_db = check_tile_collision(_prf_db, _fp_db, false, noone, true);
                var _hic_db = check_tile_collision(_pc_db, _fp_db, false, noone, true);
                _clear_db = !_hil_db && !_hic_db && !_hir_db;
                if (!_clear_db && !_hil_db && !_hir_db) {
                    _clear_db = true;
                }
            }
        }
        if (!_clear_db) vsp = grv;
    }

    // --- 6x3. AIR HANG BREAKER (after 6x/6x2) ---
    // If physics says !grounded but vsp is still 0 after the vertical stack, always seed one gravity step.
    // §2 can clear grounded while touch_floor_for_ground && touch_stand_for_ground stay true (anchor / shelf vote
    // mismatch on full-block lips) — the old inner guard skipped those frames and the stall could persist.
    if (!grounded && global.tilemap_collision_id != noone && stunTimer <= 0 && abs(vsp) <= 0.001) {
        vsp = grv;
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
    // Skip when vsp==0: at a lip stall peel's x±1 nudges fight strict vertical resolution and read as edge jitter.
    if (global.tilemap_collision_id != noone && !grounded && vsp != 0) {
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

    // Air: vertical can move y down but §6d peel / lip separation can push y back up the same frame — gravity still
    // stacks vsp so HUD shows huge vsp with almost no net drop, then one frame clears and you "snap" fall. Cap when
    // net motion stayed tiny while vsp grew unrealistically.
    if (!grounded && stunTimer <= 0 && vsp > grv * 5) {
        var _y_delta_vp = y - _y_pre_vertical;
        if (_y_delta_vp < grv * 3) vsp = min(vsp, grv * 4);
    }

    // --- 6a. GROUND SNAP (grounded only) ---
    // When !grounded but vsp was zeroed by collision (lip / coyote), snapping y+ here fought vertical resolution
    // and peel — visible edge jitter. Flush-to-floor for true ground contact only; 6c + next frame §2 handle land.
    if (global.tilemap_collision_id != noone && vsp == 0 && grounded) {
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
        } else if (FULL_BLOCK_EDGE_GROUND_FORGIVE) {
            // Full-block lip teeter: skip full 6a snap to avoid jitter, but allow a single flush pixel so feet sit on the surface.
            feet_y = floor(bbox_bottom);
            var _pl6t = floor(bbox_left) + 1;
            var _pr6t = floor(bbox_right) - 1;
            var _pc6t = floor((bbox_left + bbox_right) * 0.5);
            var _fc6t = check_tile_collision(_pc6t, feet_y);
            var _fl6t = check_tile_collision(_pl6t, feet_y);
            var _fr6t = check_tile_collision(_pr6t, feet_y);
            if (!(_fc6t || _fl6t || _fr6t)) {
                var _u16t = check_tile_collision(_pc6t, feet_y + GROUND_CHECK_DIST)
                    || check_tile_collision(_pl6t, feet_y + GROUND_CHECK_DIST)
                    || check_tile_collision(_pr6t, feet_y + GROUND_CHECK_DIST);
                if (_u16t) y += 1;
            }
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
    var _votes_needed = GROUND_LAND_VOTES_MIN_AIR;
    var _ix_ln = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_left_now, _fpy_now) : -1;
    var _ix_cn = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_center_now, _fpy_now) : -1;
    var _ix_rn = (_tm6c != noone) ? tilemap_shelf_index_at_pixel(_tm6c, _p_right_now, _fpy_now) : -1;
    var _shelf_strict_34_36_now = (_ix_ln == 34 || _ix_ln == 36 || _ix_cn == 34 || _ix_cn == 36 || _ix_rn == 34 || _ix_rn == 36);
    var _shelf_cap_feet_6c = (_tm6c != noone) && tilemap_shelf_cap_near_feet(_tm6c, _p_left_now, _p_center_now, _p_right_now, _feet_y_now);
    var _shelf_touch_tile1_now = (_ix_ln == 1 || _ix_cn == 1 || _ix_rn == 1);
    var _vsp_lim_6c = SHELF_STAND_VSP_ABS_MAX;
    if (_shelf_touch_tile1_now) _vsp_lim_6c = min(_vsp_lim_6c, SHELF_STAND_VSP_TILE1);
    var _strict3426_6c = _shelf_strict_34_36_now && _shelf_cap_feet_6c
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
        var _toe_raw_now = check_tile_collision(_p_left_now, _fpy_now) || check_tile_collision(_p_right_now, _fpy_now);
        var _full_lip_ok = FULL_BLOCK_EDGE_GROUND_FORGIVE && _raw_floor_any_now && _span_lr_full <= CAP_GROUND_CELL_SPAN_MAX
            && (_raw_floor_now >= 2 || (_raw_floor_now >= 1 && _toe_raw_now));
        _on_ground_now = (_floor_votes_now >= _votes_needed) && (
            (_raw_floor_now >= GROUND_LAND_VOTES_MIN_AIR && _center_floor_now) ||
            _full_lip_ok
        );
    }
    if (_on_ground_now) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        air_chain_jump_used = false;
    }
    if (shelf_threshold_snap_this_step) {
        grounded = true;
        coyote_time_timer = coyote_time_max;
        jump_count = 0;
        air_chain_jump_used = false;
    }
    if (grounded && vsp > 0.001 && stunTimer <= 0) vsp = 0;

    // --- 6x4. POST-6c NEAR-ZERO VSP SEED (final bbox after peel/snap; float dust can skip strict vsp==0 checks) ---
    if (!grounded && global.tilemap_collision_id != noone && stunTimer <= 0 && abs(vsp) <= 0.001) {
        vsp = grv;
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
    // When full_lip_anim_sticky is active, center probe can hiccup true for one frame while toes still hug the lip; without this,
    // _teeter_anim drops out → _anim_grounded false → jump peak/fall with image_speed 0 while y barely moves (felt "stall").
    var _teeter_toe_floor = (_raw_l_teet || _raw_r_teet) && (!_raw_c_teet || full_lip_anim_sticky > 0);
    var _teeter_anim = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_shelf_any_near_feet_pose && _teeter_toe_floor && _span_teet <= CAP_GROUND_CELL_SPAN_MAX
        && wall_side == 0 && abs(vsp) <= 2 && !_torso_overlap_pose && !_feet_embed_pose;
    var _anim_grounded = grounded || _teeter_anim;

    if (!attacking) {
        if (_anim_grounded) {
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
                    // Skip crouch if moving (unless forced landing crouch is still playing)
                    sprite_index = (is_dashing) ? spr_mc_dash : spr_mc_jog;
                    image_index = 0;
                } else if (image_index >= ANIM_LAND_CROUCH_END) {
                    sprite_index = spr_mc_idle;
                    image_index = 0;
                    force_landing_crouch = false;
                }
            } else if (sprite_index == spr_mc_walljump) {
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
            // Air logic — wall cling / wall-jump pose (MMX wall_slide + wall_jump anim), then jump rise / peak / fall
            if (wall_jump_kick_hold_timer > 0) {
                sprite_index = spr_mc_walljump;
                image_index = 1;
                image_speed = 0;
                image_xscale = -wall_side * image_base_scale;
            } else if (wall_jump_extend_timer > 0) {
                sprite_index = spr_mc_jump;
                image_speed = 1;
                image_xscale = last_direction * image_base_scale;
                if (vsp < JUMP_RISE_THRESHOLD) {
                    image_index = 0;
                } else if (vsp >= JUMP_PEAK_MIN && vsp <= JUMP_PEAK_MAX) {
                    image_index = 2;
                    image_speed = 0;
                } else {
                    image_speed = 0;
                    hair_flicker_counter++;
                    if (hair_flicker_counter >= ANIM_HAIR_FLICKER_INTERVAL) hair_flicker_counter = 0;
                    image_index = (hair_flicker_counter < ANIM_HAIR_FLICKER_THRESHOLD) ? 5 : 6;
                }
            } else if (wall_side != 0 && _input_dir == wall_side && vsp > 0) {
                sprite_index = spr_mc_walljump;
                image_index = 0;
                image_speed = 0;
                image_xscale = -wall_side * image_base_scale;
            } else {
            var _lip_fall_teeter_geom = _teeter_anim || (!_raw_c_teet && (_raw_l_teet || _raw_r_teet));
            // Sticky can linger after stepping off toward a lower floor; vsp<6 kept idle for the whole drop — only
            // use air-idle when still reading as lip teeter and vertical speed is tiny (first ticks off the edge).
            var _lip_fall_pose = FULL_BLOCK_EDGE_GROUND_FORGIVE && full_lip_anim_sticky > 0 && !_shelf_any_near_feet_pose
                && vsp > -2 && vsp <= 2 && !_torso_overlap_pose && !_feet_embed_pose && _lip_fall_teeter_geom;
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
            }
        }
    } else {
        // Keep attack swing animation at designed speed
        image_speed = 1; 
    }

    // --- 8. DIRECTION FLIPPING (with attack lock; wall jump / wall slide facing) ---
    if (wall_jump_lock > 0) {
        var _move_dir = sign(hsp);
        if (_move_dir != 0) {
            image_xscale = (_move_dir > 0) ? image_base_scale : -image_base_scale;
            last_direction = _move_dir;
        }
    } else if (wall_side != 0 && !_anim_grounded && _input_dir == wall_side && vsp > 0) {
        image_xscale = -wall_side * image_base_scale;
        last_direction = -wall_side;
    } else if (_input_dir != 0 && stunTimer <= 0 && !attacking) {
        image_xscale = (_input_dir > 0) ? image_base_scale : -image_base_scale;
        last_direction = _input_dir;
    } else if (attacking && stunTimer <= 0) {
        if (last_direction != 0) image_xscale = last_direction * image_base_scale;
    }

    // --- 8b. FEET FLUSH AFTER ANIM / FACING ---
    // Multi-step flush is skipped on full-block lip teeter / sticky (jitter). Single-pixel flush still removes hover.
    var _full_block_teeter_skip_8b = FULL_BLOCK_EDGE_GROUND_FORGIVE && !_cap_under_mc && !_center_floor_pose;
    var _skip8b_flush = _full_block_teeter_skip_8b || (FULL_BLOCK_EDGE_GROUND_FORGIVE && full_lip_anim_sticky > 0);
    if (global.tilemap_collision_id != noone && grounded && vsp == 0 && wall_side == 0 && !attacking) {
        feet_y = floor(bbox_bottom);
        var _pl0b = floor(bbox_left) + 1;
        var _pr0b = floor(bbox_right) - 1;
        var _pc0b = floor((bbox_left + bbox_right) * 0.5);
        if (!_skip8b_flush) {
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
        } else if (FULL_BLOCK_EDGE_GROUND_FORGIVE) {
            feet_y = floor(bbox_bottom);
            var _fc8t = check_tile_collision(_pc0b, feet_y);
            var _fl8t = check_tile_collision(_pl0b, feet_y);
            var _fr8t = check_tile_collision(_pr0b, feet_y);
            if (!(_fc8t || _fl8t || _fr8t)) {
                var _u18t = check_tile_collision(_pc0b, feet_y + GROUND_CHECK_DIST)
                    || check_tile_collision(_pl0b, feet_y + GROUND_CHECK_DIST)
                    || check_tile_collision(_pr0b, feet_y + GROUND_CHECK_DIST);
                if (_u18t) y += 1;
            }
        }
    }
    
    if (post_attack_accel_timer > 0) post_attack_accel_timer--;
    if (grounded) {
        side_entry_airborne_frames = 0;
        wall_jump_extend_timer = 0;
        wall_jump_kick_hold_timer = 0;
        wall_kick_cooldown = 0;
        wall_kick_from_side = 0;
    } else {
        side_entry_airborne_frames = min(side_entry_airborne_frames + 1, 300);
    }
    if (wall_jump_lock > 0) wall_jump_lock--;
    if (wall_jump_extend_timer > 0) wall_jump_extend_timer--;
    if (wall_jump_kick_hold_timer > 0) wall_jump_kick_hold_timer--;
    if (wall_kick_cooldown > 0) wall_kick_cooldown--;

    // --- DEBUG: ledge air-stall (set DEBUG_LEDGE_AIR_STALL = true in obj_player Create) ---
    if (DEBUG_LEDGE_AIR_STALL) {
        ledge_dbg_line = "";
        var _ldb_eps = DEBUG_LEDGE_LOG_VSP_MAX;
        if (!grounded && global.tilemap_collision_id != noone && stunTimer <= 0 && abs(vsp) <= _ldb_eps) {
            feet_y = floor(bbox_bottom);
            var _db_pc = floor((bbox_left + bbox_right) * 0.5);
            var _db_pl = floor(bbox_left) + 1;
            var _db_pr = floor(bbox_right) - 1;
            var _db_fy1 = feet_y + 1;
            var _db_blk_dn = check_tile_collision(_db_pl, _db_fy1) || check_tile_collision(_db_pc, _db_fy1) || check_tile_collision(_db_pr, _db_fy1);
            var _db_fp = feet_y + GROUND_CHECK_DIST;
            var _db_raw_n = (check_tile_collision(_db_pc, _db_fp) ? 1 : 0) + (check_tile_collision(_db_pl, _db_fp) ? 1 : 0) + (check_tile_collision(_db_pr, _db_fp) ? 1 : 0);
            ledge_dbg_line = "dn1=" + string(_db_blk_dn) + " fl3=" + string(_db_raw_n) + " lip=" + string(full_lip_anim_sticky) + " coy=" + string(coyote_time_timer)
                + " snap=" + string(shelf_threshold_snap_this_step) + " mv=" + string(can_move) + " atk=" + string(attacking);
            show_debug_message("LEDGE_AIR t=" + string(current_time) + " xy=" + string(floor(x)) + "," + string(floor(y))
                + " vsp=" + string(vsp) + " hsp=" + string(hsp) + " " + ledge_dbg_line);
        }
    }

    shelf_bb_bottom_prev = bbox_bottom;
}