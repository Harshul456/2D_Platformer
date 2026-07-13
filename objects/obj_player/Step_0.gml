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

// Toggle enemy LOS / raycast overlay (F3)
if (keyboard_check_pressed(vk_f3)) {
    scr_enemy_raycast_debug_toggle();
}

// Toggle borderless fullscreen (F11)
if (keyboard_check_pressed(DISPLAY_BORDERLESS_TOGGLE_KEY)) {
    scr_display_toggle_borderless();
}

// 1. PROCESS NORMAL MOVEMENT
scr_player_movement();
scr_player_ground_debris_step();
scr_player_saber_trail_step();
scr_player_footsteps_step();

// Hits can land after attack Step (collision order) or same frame as knockback — never keep swing physics while stunned.
if (stunTimer > 0 && attacking) {
    attacking = false;
    attack_lockout = 0;
    attack_commit_lock = 0;
    attack_recovery_lock = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
    combo_buffer = false;
    attack_shift_remaining = 0;
    attack_recovery_cut = false;
    comboTimer = 0;
    comboCount = 0;
    scr_player_saber_trail_clear();
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
// Skip if attack_recovery_lock > 0: atk2 finisher recovery — no new attack until lock expires
if (!attacking && stunTimer <= 0 && attack_lockout <= 0 && attack_recovery_grace <= 0
    && attack_recovery_lock <= 0 && attack_buffer_timer > 0 && attackCooldownTimer <= 0 && grounded) {
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
        sprint_reel_dir_wait = 0;
        sprint_committed = false;
        sprint_burst_tick = 0;
        sprint_commit_dir = 0;
        sprint_hold_latched = false;
        sprint_z_idle_charged = false;
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
        var _shifted = 0;
        repeat (_n) {
            var _cy = floor((bbox_top + bbox_bottom) * 0.5);
            var _side = (_step > 0) ? floor(bbox_right) : floor(bbox_left);
            if (!check_tile_collision(_side + _step, _cy)) {
                x += _step;
                attack_shift_remaining -= 1;
                _shifted += 1;
            } else {
                attack_shift_remaining = 0;
                break;
            }
        }
        if (_shifted > 0) {
            scr_player_ground_debris_on_attack_shift(_shifted);
        }
    }
    
    // --- HIT DETECTION + SABER TRAIL ---
    var _hb = scr_player_attack_compute_hitbox();
    if (_hb.active) {
        debug_hitbox_x1 = _hb.x1;
        debug_hitbox_y1 = _hb.y1;
        debug_hitbox_x2 = _hb.x2;
        debug_hitbox_y2 = _hb.y2;
        debug_hitbox_active = true;
        scr_player_saber_trail_spawn_edge(_hb);
    }

    if (_hb.active && !attack_has_hit) {
        var x1 = _hb.x1;
        var y1 = _hb.y1;
        var x2 = _hb.x2;
        var y2 = _hb.y2;
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
            var _hitstop_frames = (comboCount >= 2) ? ATTACK_FINISHER_HITSTOP : ATTACK_LIGHT_HITSTOP;
            scr_hitstop_trigger(_hitstop_frames);
            hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK;
            if (comboCount >= 2) {
                hsp -= last_direction * ATTACK_COMBO2_PLAYER_RECOIL;
            } else if (comboCount == 1) {
                scr_player_attack1_prepare_retreat();
            }
        } else if (_hit_enemy != noone) {
            var _hit_result = { landed: false, intercepted: false, armored_chip: false, super_armor: false };
            with (_hit_enemy) {
                _hit_result = scr_enemy_on_player_hit(other.comboCount);
            }

            attack_has_hit = true;

            if (_hit_result.intercepted) {
                if (_hit_result.super_armor) {
                    // Super armor dash — disrespect punished; enemy keeps slicing.
                    scr_hitstop_trigger(4);
                    hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK * 1.4;
                    attack_shift_remaining = 0;
                    attack_lockout = max(attack_lockout, 12);
                    combo_buffer = false;
                    attack_chain_latched = false;
                } else {
                    scr_hitstop_trigger(1);
                    hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK * 0.35;
                }
            } else if (_hit_result.armored_chip) {
                // Regular armor telegraph — chip damage only, tell continues.
                scr_hitstop_trigger(1);
                hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK * 0.15;
            } else if (_hit_result.landed) {
                var _hitstop_frames = (comboCount >= 2) ? ATTACK_FINISHER_HITSTOP : ATTACK_LIGHT_HITSTOP;
                scr_hitstop_trigger(_hitstop_frames);

                if (scr_player_is_downward_air_strike() && bbox_bottom <= _hit_enemy.bbox_top + 28) {
                    scr_player_apply_nail_pogo();
                } else {
                    hsp -= last_direction * ATTACK_ON_HIT_PUSHBACK;
                    if (comboCount >= 2) {
                        hsp -= last_direction * ATTACK_COMBO2_PLAYER_RECOIL;
                    } else if (comboCount == 1) {
                        scr_player_attack1_prepare_retreat();
                    }
                }
            }
        }
    }
    if (!_hb.active) debug_hitbox_active = false;

    // Atk2 commit lock — heavy finisher holds player in the swing (no dash cancel).
    if (attack_commit_lock > 0) {
        attack_commit_lock--;
        hsp = lerp(hsp, 0, 0.45);
        if (abs(hsp) < 0.4) hsp = 0;
    }

    // Atk1 early endlag — poke-and-run after solo hit.
    if (attack_recovery_cut && comboCount == 1) {
        var _cancel_after = (variable_instance_exists(id, "ATTACK1_HIT_CANCEL_AFTER_INDEX")
            ? ATTACK1_HIT_CANCEL_AFTER_INDEX : 2);
        if (image_index > _cancel_after) {
            var _post_accel = (variable_instance_exists(id, "ATTACK1_HIT_POST_ACCEL_FRAMES")
                ? ATTACK1_HIT_POST_ACCEL_FRAMES : 4);
            scr_player_attack_end_swing(_post_accel);
        }
    } else if (image_index >= image_number - 1) {
        var _post_accel = POST_ATTACK_ACCEL_FRAMES;
        if (attack_has_hit && comboCount == 1) {
            _post_accel = (variable_instance_exists(id, "ATTACK1_HIT_POST_ACCEL_FRAMES")
                ? ATTACK1_HIT_POST_ACCEL_FRAMES : 4);
        } else if (attack_has_hit && comboCount >= 2) {
            _post_accel = (variable_instance_exists(id, "ATTACK2_HIT_POST_ACCEL_FRAMES")
                ? ATTACK2_HIT_POST_ACCEL_FRAMES : 12);
        }
        scr_player_attack_end_swing(_post_accel);
    }
}

// Hit / interrupt can leave attacking=false while debug_hitbox_active was true — clear it here.
if (!attacking) {
    debug_hitbox_active = false;
}

// 4. DECREMENT TIMERS
if (attack_commit_lock > 0 && !attacking) attack_commit_lock = 0;
if (attack_recovery_lock > 0) attack_recovery_lock--;
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

// Bulb player light (warm glow; follows each Step)
if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
    if (!BULB_PLAYER_TORCH_ENABLED) {
        if (bulb_light != undefined) {
            bulb_light.visible = false;
        }
    } else {
        var _crystal = scr_bulb_player_crystal_influence(x, y - 16);

        var _torch_warm = make_colour_rgb(255, 235, 190);

        if (bulb_light == undefined) {
            bulb_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
            bulb_light.intensity = BULB_PLAYER_TORCH_INTENSITY;
            bulb_light.blend = _torch_warm;
            bulb_light.penumbraSize = 0;
            bulb_light.xscale = BULB_PLAYER_TORCH_SCALE;
            bulb_light.yscale = BULB_PLAYER_TORCH_SCALE;
            bulb_light.castShadows = false;
            bulb_light.normalMap = global.bulb_normal_maps_enabled;
            bulb_light.normalMapZ = 40;
        } else {
            bulb_light.visible = true;
            bulb_light.x = x;
            bulb_light.y = y + BULB_PLAYER_TORCH_Y_OFFSET;
            bulb_light.normalMap = global.bulb_normal_maps_enabled;
            bulb_light.normalMapZ = 40;
        }

        bulb_light.xscale = BULB_PLAYER_TORCH_SCALE;
        bulb_light.yscale = BULB_PLAYER_TORCH_SCALE;
        bulb_light.castShadows = false;
        bulb_light.intensity = lerp(BULB_PLAYER_TORCH_INTENSITY, BULB_PLAYER_TORCH_INTENSITY * BULB_PLAYER_TORCH_CRYSTAL_DIM, _crystal.strength);
        bulb_light.blend = merge_colour(_torch_warm, _crystal.blend, _crystal.strength * 0.65);
    }
}

// 5. VISUALS & CLEANUP
scr_player_footsteps_cooldown_tick();
scr_player_invincibility();
_player_sprint_deform();

// NOTE:
// Keep sub-pixel positions for smoother movement. Draw events already snap to pixels where needed.