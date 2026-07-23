/// Perfect Dodge + Dodge Counter (Wuthering Waves / Bayonetta-style).
/// Dash i-frames through an active enemy attack hitbox → global slow-mo flip → X for counter.

enum DODGE_COUNTER_PHASE {
    VANISH,
    FLURRY,
    REAPPEAR
}

/// @function scr_time_scale_get
function scr_time_scale_get() {
    if (!variable_global_exists("time_scale")) return 1;
    return clamp(global.time_scale, 0.01, 1);
}

/// @function scr_time_scale_set
function scr_time_scale_set(_scale) {
    global.time_scale = clamp(_scale, 0.01, 1);
    if (global.time_scale >= 0.999) {
        global.time_scale = 1;
        global.time_scale_accum = 0;
        global.time_scale_logic_tick = true;
    }
}

/// @function scr_time_scale_begin_frame
/// @description Call once per Step from obj_player (enemies spawn after player in room order).
function scr_time_scale_begin_frame() {
    if (!variable_global_exists("time_scale_accum")) global.time_scale_accum = 0;
    var _ts = scr_time_scale_get();
    if (_ts >= 0.999) {
        global.time_scale_logic_tick = true;
        global.time_scale_accum = 0;
        return;
    }
    global.time_scale_accum += _ts;
    global.time_scale_logic_tick = (global.time_scale_accum >= 1);
    if (global.time_scale_logic_tick) global.time_scale_accum -= 1;
}

/// @function scr_time_scale_should_tick
/// @description True when world AI/physics should advance this frame (shared across enemies).
function scr_time_scale_should_tick() {
    if (!variable_global_exists("time_scale_logic_tick")) return true;
    return global.time_scale_logic_tick;
}

/// @function scr_player_find_perfect_dodge_threat
/// @description Enemy whose active attack hitbox currently overlaps the player. Returns instance id or noone.
function scr_player_find_perfect_dodge_threat() {
    var _threat = noone;
    with (obj_enemy_parent) {
        // Crystal / HK slash hitbox
        if (variable_instance_exists(id, "state") && state == ENEMY_STATE.ATTACK) {
            var _hb = scr_enemy_attack_compute_hitbox();
            if (_hb.active
                && collision_rectangle(_hb.x1, _hb.y1, _hb.x2, _hb.y2, other, false, true) != noone) {
                _threat = id;
            }
        }
        // Grounded lunge — body is the active threat during ATTACK
        else if (variable_instance_exists(id, "gnd_state") && gnd_state == GND_STATE_ATTACK) {
            if (place_meeting(x, y, other)) {
                _threat = id;
            }
        }
        if (_threat != noone) break;
    }
    return _threat;
}

/// @function scr_player_is_dash_invincible
/// @description True while dash i-frames (or active dash commit) can Perfect Dodge.
function scr_player_is_dash_invincible() {
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) return true;
    if (variable_instance_exists(id, "sprint_committed") && sprint_committed
        && variable_instance_exists(id, "sprint_dash_standstill") && sprint_dash_standstill) {
        return true;
    }
    return false;
}

/// @function scr_player_perfect_dodge_try_trigger
/// @description Call while ALIVE during dash i-frames.
function scr_player_perfect_dodge_try_trigger() {
    if (state != PLAYER_STATE.ALIVE) return false;
    if (variable_instance_exists(id, "perfect_dodge_used") && perfect_dodge_used) return false;
    if (!scr_player_is_dash_invincible()) return false;

    var _threat = scr_player_find_perfect_dodge_threat();
    if (_threat == noone) return false;

    perfect_dodge_used = true;
    perfect_dodge_target = _threat;
    state = PLAYER_STATE.PERFECT_DODGE_SLOWMO;
    perfect_dodge_timer = variable_instance_exists(id, "PERFECT_DODGE_WINDOW_FRAMES")
        ? PERFECT_DODGE_WINDOW_FRAMES : 45;
    perfect_dodge_window_max = perfect_dodge_timer;
    perfect_dodge_ghost_tick = 0;

    // Soft-stop the dash — flip *through* the enemy to their far side
    sprint_committed = false;
    is_sprinting = false;
    sprint_burst_tick = 0;
    sprint_hold_latched = false;
    sprint_dash_standstill = false;

    // Travel direction: dash direction (into them), falling back to toward the threat
    var _through = (last_direction != 0) ? last_direction : sign(image_xscale);
    if (_through == 0 && instance_exists(_threat)) _through = sign(_threat.x - x);
    if (_through == 0) _through = 1;
    perfect_dodge_through_dir = _through;
    last_direction = _through;
    image_xscale = _through * image_base_scale;

    // Aim past the enemy's far edge so the flip lands on the other side
    var _clear = variable_instance_exists(id, "PERFECT_DODGE_CLEAR_PX")
        ? PERFECT_DODGE_CLEAR_PX : 20;
    var _coast = variable_instance_exists(id, "PERFECT_DODGE_COAST_HSP")
        ? PERFECT_DODGE_COAST_HSP : 4.2;
    var _cmin = variable_instance_exists(id, "PERFECT_DODGE_COAST_MIN")
        ? PERFECT_DODGE_COAST_MIN : 3.2;
    var _cmax = variable_instance_exists(id, "PERFECT_DODGE_COAST_MAX")
        ? PERFECT_DODGE_COAST_MAX : 5.5;
    var _hop = variable_instance_exists(id, "PERFECT_DODGE_HOP_VSP")
        ? PERFECT_DODGE_HOP_VSP : -4.6;

    if (instance_exists(_threat)) {
        var _far = (_through > 0) ? (_threat.bbox_right + _clear) : (_threat.bbox_left - _clear);
        var _need = abs(_far - x);
        // Cover the short cross in most of the window (not a long skate)
        var _frames = max(16, perfect_dodge_timer * 0.75);
        _coast = clamp(_need / _frames, _cmin, _cmax);
    }
    hsp = _through * _coast;
    vsp = _hop;

    // Flip sprite override (double-jump anim scrubbed across the window)
    sprite_index = spr_mc_doublejump;
    image_index = 0;
    image_speed = 0;
    double_jump_anim_active = true;

    var _slow = variable_instance_exists(id, "PERFECT_DODGE_TIME_SCALE")
        ? PERFECT_DODGE_TIME_SCALE : 0.38;
    scr_time_scale_set(_slow);

    // Tiny punch only — Bayonetta slows time, it doesn't freeze the world
    var _hs = variable_instance_exists(id, "PERFECT_DODGE_HITSTOP")
        ? PERFECT_DODGE_HITSTOP : 0;
    if (_hs > 0) scr_hitstop_trigger(_hs);
    scr_camera_trigger_shake(2, 6);

    // Frame-0 shing flare + icy distortion glow circle (same system as enemy hits)
    instance_create_depth(x, y - 8, depth - 1, obj_dodge_shing_flare);
    scr_player_perfect_dodge_spawn_focus_distort(1.35);
    perfect_dodge_distort_fired = true;
    // Blue focus circle waits until the expanding distort ring finishes
    perfect_dodge_aura_timer = HIT_DISTORT_LIFE;

    // Keep brief safety i-frames through the window
    dash_iframe_timer = max(dash_iframe_timer, perfect_dodge_timer);
    return true;
}

/// @function scr_player_perfect_dodge_end_slowmo
function scr_player_perfect_dodge_end_slowmo() {
    scr_time_scale_set(1);
    if (state == PLAYER_STATE.PERFECT_DODGE_SLOWMO) {
        state = PLAYER_STATE.ALIVE;
    }
    perfect_dodge_timer = 0;
    image_speed = 1;
    image_blend = c_white;
    double_jump_anim_active = false;
}

/// @function scr_player_dodge_counter_compute_landing
/// @description Strike stand position facing the threat (close enough to connect).
function scr_player_dodge_counter_compute_landing() {
    var _off = variable_instance_exists(id, "DODGE_COUNTER_STRIKE_OFFSET")
        ? DODGE_COUNTER_STRIKE_OFFSET : 28;
    var _face = (last_direction != 0) ? last_direction : 1;
    dodge_counter_from_x = x;
    dodge_counter_from_y = y;
    dodge_counter_to_x = x + _face * 36;
    dodge_counter_to_y = y;

    if (instance_exists(perfect_dodge_target)) {
        // Stand on the side we're attacking from (face toward enemy center)
        dodge_counter_to_x = perfect_dodge_target.x - _face * _off;
        dodge_counter_to_y = perfect_dodge_target.y;
        // Keep roughly our current feet height if possible
        if (variable_instance_exists(id, "bbox_bottom") && variable_instance_exists(perfect_dodge_target, "bbox_bottom")) {
            dodge_counter_to_y = y + (perfect_dodge_target.bbox_bottom - bbox_bottom);
        }
    }
}

/// @function scr_player_begin_dodge_counter
/// @description Vanish → flurry streak → reappear counter (spr_mc_flurry_attack).
function scr_player_begin_dodge_counter() {
    scr_time_scale_set(1);
    state = PLAYER_STATE.DODGE_COUNTER;
    perfect_dodge_timer = 0;
    double_jump_anim_active = false;

    // Face the threat we slipped through
    if (instance_exists(perfect_dodge_target)) {
        var _dir = sign(perfect_dodge_target.x - x);
        if (_dir != 0) {
            last_direction = _dir;
            image_xscale = last_direction * image_base_scale;
        }
    } else {
        scr_player_apply_attack_facing();
    }

    comboCount = 2;
    comboTimer = comboCooldown;
    attacking = true;
    attack_has_hit = false;
    attack_recovery_cut = false;
    attack_timer = 0;
    attack_priority_timer = 20;
    attack_chain_latched = false;
    combo_buffer = false;
    dodge_counter_strike = true;
    dodge_counter_hidden = false;
    dodge_counter_phase = DODGE_COUNTER_PHASE.VANISH;
    dodge_counter_phase_timer = variable_instance_exists(id, "DODGE_COUNTER_VANISH_FRAMES")
        ? DODGE_COUNTER_VANISH_FRAMES : 5;
    dodge_counter_flurry_frame = 0;
    dodge_counter_flurry_hold = 0;
    dodge_counter_hit_cd = 0;
    dodge_counter_hit_count = 0;
    dodge_counter_land_hold = 0;
    scr_player_saber_trail_clear();
    scr_player_dodge_counter_compute_landing();

    hsp = 0;
    vsp = 0;
    attack_shift_remaining = 0;
    attack_commit_lock = 0;

    // Freeze current pose for the vanish burst (body fades, then flurry takes over)
    image_speed = 0;
    image_blend = make_color_rgb(160, 230, 255);

    // Burst of afterimages at the vanish point
    repeat (3) {
        scr_player_perfect_dodge_spawn_ghost();
    }
    instance_create_depth(x, y - 10, depth - 1, obj_dodge_shing_flare);

    // Cancel dash leftovers
    is_sprinting = false;
    sprint_committed = false;
    sprint_reel_active = false;
    sprint_reel_pending = false;
    dash_input_buffer = 0;
    attack_buffer_timer = 0;

    // Safety i-frames through the whole counter
    var _iframe = dodge_counter_phase_timer
        + (sprite_get_number(spr_mc_flurry_attack)
            * (variable_instance_exists(id, "DODGE_COUNTER_FLURRY_FRAME_HOLD")
                ? DODGE_COUNTER_FLURRY_FRAME_HOLD : 6))
        + (variable_instance_exists(id, "DODGE_COUNTER_REAPPEAR_FRAMES")
            ? DODGE_COUNTER_REAPPEAR_FRAMES : 18)
        + ((variable_instance_exists(id, "ANIM_LAND_CROUCH_END") ? ANIM_LAND_CROUCH_END : 10)
            - (variable_instance_exists(id, "ANIM_LAND_CROUCH_START") ? ANIM_LAND_CROUCH_START : 8) + 1)
            * (variable_instance_exists(id, "DODGE_COUNTER_LAND_FRAME_HOLD")
                ? DODGE_COUNTER_LAND_FRAME_HOLD : 5);
    dash_iframe_timer = max(dash_iframe_timer, _iframe);
}

/// @function scr_player_dodge_counter_move_toward
/// @description Soft step toward landing without tunneling walls.
function scr_player_dodge_counter_move_toward(_tx, _ty, _rate) {
    var _nx = lerp(x, _tx, _rate);
    var _ny = lerp(y, _ty, _rate);
    var _dx = _nx - x;
    var _dy = _ny - y;
    var _tm = (variable_global_exists("tilemap_collision_id")) ? global.tilemap_collision_id : noone;

    var _sx = sign(_dx);
    var _n = ceil(abs(_dx));
    repeat (_n) {
        if (_sx == 0) break;
        var _px = x + _sx;
        var _blocked = place_meeting(_px, y, obj_solid) || place_meeting(_px, y, obj_wall);
        if (!_blocked && _tm != noone && _tm != -1) {
            _blocked = tilemap_point_solid(_tm, _px, y)
                || tilemap_point_solid(_tm, _px, bbox_top + 4)
                || tilemap_point_solid(_tm, _px, bbox_bottom - 4);
        }
        if (_blocked) break;
        x = _px;
    }

    var _sy = sign(_dy);
    _n = ceil(abs(_dy));
    repeat (_n) {
        if (_sy == 0) break;
        var _py = y + _sy;
        var _blocked_y = place_meeting(x, _py, obj_solid) || place_meeting(x, _py, obj_wall);
        if (!_blocked_y && _tm != noone && _tm != -1) {
            if (_sy > 0) {
                _blocked_y = tilemap_point_solid(_tm, x, bbox_bottom + 1);
            } else {
                _blocked_y = tilemap_point_solid(_tm, x, bbox_top - 1);
            }
        }
        if (_blocked_y) break;
        y = _py;
    }
}

/// @function scr_player_dodge_counter_flurry_sfx
/// @description Rapid overlapping clanks — reads as a flurry of hits.
function scr_player_dodge_counter_flurry_sfx(_hit_index) {
    var _clanks = [snd_clank_1, snd_clank_2, snd_clank_3];
    var _pick = irandom(array_length(_clanks) - 1);
    if (variable_instance_exists(id, "attack_clank_last")
        && _pick == attack_clank_last) {
        _pick = (_pick + 1 + irandom(1)) mod array_length(_clanks);
    }
    attack_clank_last = _pick;

    var _pitch = 1.05 + (_hit_index * 0.06) + random_range(-0.04, 0.08);
    _pitch = clamp(_pitch, 0.95, 1.55);
    var _gain = 0.55 + min(0.25, _hit_index * 0.03);
    var _prio = 13;

    if (variable_global_exists("sfx_combat_emitter")) {
        audio_play_sound_on(global.sfx_combat_emitter, _clanks[_pick], false, _prio, _gain, 0, _pitch);
    } else {
        var _snd_id = audio_play_sound(_clanks[_pick], _prio, false);
        if (_snd_id != -1) {
            audio_sound_pitch(_snd_id, _pitch);
            audio_sound_gain(_snd_id, _gain, 0);
        }
    }

    if ((_hit_index mod 2) == 0) {
        var _pick2 = (_pick + 1 + irandom(1)) mod array_length(_clanks);
        var _pitch2 = _pitch * random_range(1.08, 1.22);
        var _gain2 = _gain * 0.65;
        if (variable_global_exists("sfx_combat_emitter")) {
            audio_play_sound_on(global.sfx_combat_emitter, _clanks[_pick2], false, _prio - 1, _gain2, 0, _pitch2);
        } else {
            var _s2 = audio_play_sound(_clanks[_pick2], _prio - 1, false);
            if (_s2 != -1) {
                audio_sound_pitch(_s2, _pitch2);
                audio_sound_gain(_s2, _gain2, 0);
            }
        }
    }
}

/// @function scr_player_dodge_counter_flurry_anchor
/// @description World position for flurry FX / hits — pinned to the enemy body.
function scr_player_dodge_counter_flurry_anchor() {
    if (instance_exists(perfect_dodge_target)) {
        return {
            x: perfect_dodge_target.x,
            y: (perfect_dodge_target.bbox_top + perfect_dodge_target.bbox_bottom) * 0.5
        };
    }
    return {
        x: x,
        y: (bbox_top + bbox_bottom) * 0.5
    };
}

/// @function scr_player_dodge_counter_apply_chip
/// @description Damage a target with NO knockback — keeps them planted for the barrage.
function scr_player_dodge_counter_apply_chip(_target, _dmg) {
    if (!instance_exists(_target) || _dmg <= 0) return false;

    var _landed = false;

    with (_target) {
        if (variable_instance_exists(id, "obj_enemy_health")) {
            var _policy = scr_enemy_hit_armor_policy();
            if (!_policy.intercept) {
                hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
                obj_enemy_health -= _dmg * _policy.damage_mult;

                // Same distortion glow circle as a normal light hit (full strength each tick)
                scr_enemy_hit_react_trigger(1);

                knockbackX = 0;
                knockback_pending_x = 0;
                knockback_pending_y = 0;
                knockback_pending_lift = false;
                hsp = 0;

                if (obj_enemy_health <= 0 && state != ENEMY_STATE.DEATH) {
                    scr_enemy_begin_death();
                } else if (_policy.take_stun && state != ENEMY_STATE.DEATH) {
                    state = ENEMY_STATE.STUNNED;
                    stunTimer = max(stunTimer, 10);
                    image_blend = c_white;
                }
                _landed = true;
            }
        } else if (variable_instance_exists(id, "gnd_hp")) {
            if (gnd_state != GND_STATE_DEAD) {
                gnd_hp -= _dmg;
                hit_blink_timer = other.ATTACK_HIT_BLINK_FRAMES;
                gnd_knock_h = 0;
                // Grounded foes still get the screen-space shockwave + light burst
                scr_hit_distort_add(x, (bbox_top + bbox_bottom) * 0.5, 1);
                if (gnd_hp <= 0) {
                    gnd_state = GND_STATE_DEAD;
                } else {
                    gnd_state = GND_STATE_DAMAGED;
                    gnd_hurt_stun_timer = max(
                        variable_instance_exists(id, "gnd_hurt_stun_timer") ? gnd_hurt_stun_timer : 0,
                        8
                    );
                }
                _landed = true;
            }
        }
    }

    return _landed;
}

/// @function scr_player_dodge_counter_target_dead
/// @description True if the Perfect Dodge threat is gone / shattered / HP depleted.
function scr_player_dodge_counter_target_dead() {
    if (!instance_exists(perfect_dodge_target)) return true;
    with (perfect_dodge_target) {
        if (variable_instance_exists(id, "state") && state == ENEMY_STATE.DEATH) return true;
        if (variable_instance_exists(id, "obj_enemy_health") && obj_enemy_health <= 0) return true;
        if (variable_instance_exists(id, "gnd_state") && gnd_state == GND_STATE_DEAD) return true;
        if (variable_instance_exists(id, "gnd_hp") && gnd_hp <= 0) return true;
    }
    return false;
}

/// @function scr_player_dodge_counter_begin_reappear
/// @description Jump from vanish/flurry into the soft landing reappear.
function scr_player_dodge_counter_begin_reappear() {
    scr_player_dodge_counter_move_toward(dodge_counter_to_x, dodge_counter_to_y, 1);
    dodge_counter_phase = DODGE_COUNTER_PHASE.REAPPEAR;
    dodge_counter_phase_timer = variable_instance_exists(id, "DODGE_COUNTER_REAPPEAR_FRAMES")
        ? DODGE_COUNTER_REAPPEAR_FRAMES : 18;
    dodge_counter_hidden = false;
    debug_hitbox_active = false;

    sprite_index = spr_mc_jump;
    var _land0 = variable_instance_exists(id, "ANIM_LAND_CROUCH_START")
        ? ANIM_LAND_CROUCH_START : 8;
    image_index = _land0;
    image_speed = 0;
    dodge_counter_land_hold = variable_instance_exists(id, "DODGE_COUNTER_LAND_FRAME_HOLD")
        ? DODGE_COUNTER_LAND_FRAME_HOLD : 5;
    force_landing_crouch = true;
    image_alpha = 0;
    image_blend = make_color_rgb(180, 240, 255);
    scr_player_land_squash_trigger(4);
    instance_create_depth(x, y - 8, depth - 1, obj_dodge_shing_flare);
    scr_player_perfect_dodge_spawn_ghost();
}

/// @function scr_player_dodge_counter_try_hit
/// @description Multi-hit barrage centered on the enemy — no knockback.
function scr_player_dodge_counter_try_hit() {
    var _interval = variable_instance_exists(id, "DODGE_COUNTER_HIT_INTERVAL")
        ? DODGE_COUNTER_HIT_INTERVAL : 2;
    if (dodge_counter_hit_cd > 0) {
        dodge_counter_hit_cd--;
        return;
    }

    var _anchor = scr_player_dodge_counter_flurry_anchor();
    var _pad = 40;
    var _x1 = _anchor.x - _pad;
    var _y1 = _anchor.y - _pad;
    var _x2 = _anchor.x + _pad;
    var _y2 = _anchor.y + _pad;

    debug_hitbox_x1 = _x1;
    debug_hitbox_y1 = _y1;
    debug_hitbox_x2 = _x2;
    debug_hitbox_y2 = _y2;
    debug_hitbox_active = true;

    var _target = noone;
    if (instance_exists(perfect_dodge_target)) {
        _target = perfect_dodge_target;
    } else {
        _target = collision_rectangle(_x1, _y1, _x2, _y2, obj_enemy, false, true);
        if (_target == noone) {
            _target = collision_rectangle(_x1, _y1, _x2, _y2, obj_enemy_parent, false, true);
        }
    }
    if (_target == noone) return;

    var _chip = ATTACK_DAMAGE_PER_HIT;
    var _cmult = variable_instance_exists(id, "DODGE_COUNTER_CHIP_MULT")
        ? DODGE_COUNTER_CHIP_MULT : 0.28;
    var _dmult = variable_instance_exists(id, "DODGE_COUNTER_DAMAGE_MULT")
        ? DODGE_COUNTER_DAMAGE_MULT : 1.75;
    _chip = max(1, ceil(_chip * _cmult * _dmult));

    if (!scr_player_dodge_counter_apply_chip(_target, _chip)) return;

    dodge_counter_hit_count++;
    dodge_counter_hit_cd = _interval;
    attack_has_hit = true;

    scr_player_dodge_counter_flurry_sfx(dodge_counter_hit_count);
    scr_player_impact_lines_on_hit(_x1, _y1, _x2, _y2, _target, true);
    if ((dodge_counter_hit_count mod 3) == 1) {
        scr_camera_trigger_shake(1, 3);
    }
}

/// @function scr_player_dodge_counter_step
/// @description Vanish → flurry FX on enemy → natural reappear.
function scr_player_dodge_counter_step() {
    attack_timer++;
    mask_index = spr_mc_idle;
    hsp = 0;
    vsp = 0;

    switch (dodge_counter_phase) {
        case DODGE_COUNTER_PHASE.VANISH:
            dodge_counter_phase_timer--;
            if ((dodge_counter_phase_timer mod 2) == 0) {
                scr_player_perfect_dodge_spawn_ghost();
            }
            var _vmax = max(1, variable_instance_exists(id, "DODGE_COUNTER_VANISH_FRAMES")
                ? DODGE_COUNTER_VANISH_FRAMES : 5);
            image_alpha = clamp(dodge_counter_phase_timer / _vmax, 0, 1);
            image_blend = merge_color(c_white, make_color_rgb(140, 220, 255), 1 - image_alpha);

            if (dodge_counter_phase_timer <= 0) {
                dodge_counter_phase = DODGE_COUNTER_PHASE.FLURRY;
                dodge_counter_hidden = true;
                image_alpha = 0;
                dodge_counter_flurry_frame = 0;
                dodge_counter_flurry_hold = variable_instance_exists(id, "DODGE_COUNTER_FLURRY_FRAME_HOLD")
                    ? DODGE_COUNTER_FLURRY_FRAME_HOLD : 3;
                dodge_counter_hit_cd = 0;
                sprite_index = spr_mc_flurry_attack;
                image_index = 0;
                image_speed = 0;
                scr_player_dodge_counter_move_toward(dodge_counter_to_x, dodge_counter_to_y, 1);
                scr_player_perfect_dodge_spawn_ghost();
                scr_player_dodge_counter_flurry_sfx(0);
            }
            break;

        case DODGE_COUNTER_PHASE.FLURRY:
            dodge_counter_hidden = true;
            image_alpha = 0;
            sprite_index = spr_mc_flurry_attack;
            image_index = dodge_counter_flurry_frame;
            image_speed = 0;

            if (instance_exists(perfect_dodge_target)) {
                scr_player_dodge_counter_compute_landing();
                scr_player_dodge_counter_move_toward(dodge_counter_to_x, dodge_counter_to_y, 0.35);
            }

            scr_player_dodge_counter_try_hit();

            // Kill confirmed mid-barrage — cut flurry and land
            if (scr_player_dodge_counter_target_dead()) {
                scr_player_dodge_counter_begin_reappear();
                break;
            }

            var _frames = max(1, sprite_get_number(spr_mc_flurry_attack));
            var _hold = max(1, variable_instance_exists(id, "DODGE_COUNTER_FLURRY_FRAME_HOLD")
                ? DODGE_COUNTER_FLURRY_FRAME_HOLD : 3);

            dodge_counter_flurry_hold--;
            if (dodge_counter_flurry_hold <= 0) {
                dodge_counter_flurry_frame++;
                dodge_counter_flurry_hold = _hold;
                if (dodge_counter_flurry_frame >= _frames) {
                    scr_player_dodge_counter_begin_reappear();
                }
            }
            break;

        case DODGE_COUNTER_PHASE.REAPPEAR:
            if (dodge_counter_phase_timer > 0) dodge_counter_phase_timer--;
            var _rmax = max(1, variable_instance_exists(id, "DODGE_COUNTER_REAPPEAR_FRAMES")
                ? DODGE_COUNTER_REAPPEAR_FRAMES : 18);
            // Smoothstep fade — soft pop-in instead of a hard cut
            var _ru = 1 - (dodge_counter_phase_timer / _rmax);
            _ru = clamp(_ru, 0, 1);
            _ru = _ru * _ru * (3 - 2 * _ru);
            image_alpha = _ru;
            image_blend = merge_color(make_color_rgb(180, 240, 255), c_white, _ru);
            dodge_counter_hidden = false;
            debug_hitbox_active = false;

            // Scrub landing crouch (jump frames ANIM_LAND_CROUCH_START..END)
            sprite_index = spr_mc_jump;
            image_speed = 0;
            var _land0 = variable_instance_exists(id, "ANIM_LAND_CROUCH_START")
                ? ANIM_LAND_CROUCH_START : 8;
            var _land1 = variable_instance_exists(id, "ANIM_LAND_CROUCH_END")
                ? ANIM_LAND_CROUCH_END : 10;
            var _lhold = max(1, variable_instance_exists(id, "DODGE_COUNTER_LAND_FRAME_HOLD")
                ? DODGE_COUNTER_LAND_FRAME_HOLD : 5);

            if (image_index < _land0) image_index = _land0;
            if (image_index < _land1) {
                dodge_counter_land_hold--;
                if (dodge_counter_land_hold <= 0) {
                    image_index = min(image_index + 1, _land1);
                    dodge_counter_land_hold = _lhold;
                }
            }

            // Wait for both fade + landing crouch to finish
            var _land_done = (image_index >= _land1);
            var _fade_done = (dodge_counter_phase_timer <= 0);
            if (_fade_done && _land_done) {
                image_alpha = 1;
                image_blend = c_white;
                image_speed = 1;
                sprite_index = spr_mc_idle;
                image_index = 0;
                force_landing_crouch = false;
                attacking = false;
                attack_timer = 0;
                comboCount = 0;
                comboTimer = 0;
                post_attack_accel_timer = variable_instance_exists(id, "POST_ATTACK_ACCEL_FRAMES")
                    ? POST_ATTACK_ACCEL_FRAMES : 12;
                scr_player_dodge_counter_finished();
            } else if (_fade_done && !_land_done) {
                // Hold at full opacity while the last crouch frames play out
                dodge_counter_phase_timer = 0;
                image_alpha = 1;
                image_blend = c_white;
            }
            break;
    }
}

/// @function scr_player_dodge_counter_draw_flurry
/// @description Additive flurry FX pinned to the enemy (not the invisible player).
function scr_player_dodge_counter_draw_flurry() {
    if (!variable_instance_exists(id, "dodge_counter_phase")) return;
    if (dodge_counter_phase != DODGE_COUNTER_PHASE.FLURRY) return;

    var _anchor = scr_player_dodge_counter_flurry_anchor();
    var _fx_x = floor(_anchor.x);
    var _fx_y = floor(_anchor.y);
    var _face = (last_direction != 0) ? last_direction : 1;
    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();

    gpu_set_blendmode(bm_add);
    draw_sprite_ext(spr_mc_flurry_attack, dodge_counter_flurry_frame,
        _fx_x, _fx_y, _face, 1, 0, c_white, 1);
    draw_sprite_ext(spr_mc_flurry_attack, dodge_counter_flurry_frame,
        _fx_x, _fx_y, _face * 0.92, 0.92, 0, make_color_rgb(180, 240, 255), 0.55);
    gpu_set_blendmode(_old_blend);
    draw_set_alpha(_old_alpha);
}

/// @function scr_player_dodge_counter_finished
/// @description Call when the counter swing ends.
function scr_player_dodge_counter_finished() {
    dodge_counter_strike = false;
    dodge_counter_hidden = false;
    dodge_counter_phase = DODGE_COUNTER_PHASE.VANISH;
    dodge_counter_hit_cd = 0;
    if (state == PLAYER_STATE.DODGE_COUNTER) {
        state = PLAYER_STATE.ALIVE;
    }
    image_alpha = 1;
    image_blend = c_white;
    image_speed = 1;
    debug_hitbox_active = false;
    scr_time_scale_set(1);
}

/// @function scr_player_perfect_dodge_apply_flip_motion
/// @description Through-enemy flip: strong horizontal carry + low arc to the far side.
function scr_player_perfect_dodge_apply_flip_motion() {
    var _g = variable_instance_exists(id, "grv") ? grv : 0.5;
    var _grav_mul = variable_instance_exists(id, "PERFECT_DODGE_GRAV_MUL")
        ? PERFECT_DODGE_GRAV_MUL : 0.48;
    var _decay = variable_instance_exists(id, "PERFECT_DODGE_HSP_DECAY")
        ? PERFECT_DODGE_HSP_DECAY : 0.96;
    var _cmin = variable_instance_exists(id, "PERFECT_DODGE_COAST_MIN")
        ? PERFECT_DODGE_COAST_MIN : 3.2;
    var _dir = variable_instance_exists(id, "perfect_dodge_through_dir")
        ? perfect_dodge_through_dir : sign(hsp);
    if (_dir == 0) _dir = (last_direction != 0) ? last_direction : 1;

    // Keep a modest push only until just past the enemy, then let decay kill the skate
    if (instance_exists(perfect_dodge_target)) {
        var _clear = variable_instance_exists(id, "PERFECT_DODGE_CLEAR_PX")
            ? PERFECT_DODGE_CLEAR_PX : 20;
        var _far = (_dir > 0)
            ? (perfect_dodge_target.bbox_right + _clear)
            : (perfect_dodge_target.bbox_left - _clear);
        var _past = (_dir > 0) ? (x >= _far) : (x <= _far);
        if (!_past) {
            hsp = _dir * max(abs(hsp), _cmin);
        } else {
            // Past the mark — dump horizontal so you don't fly away
            hsp *= 0.82;
        }
    }

    vsp += _g * _grav_mul;
    vsp = clamp(vsp, -8, 8);

    var _tm = (variable_global_exists("tilemap_collision_id")) ? global.tilemap_collision_id : noone;

    // Horizontal — solids / walls / tile solids at torso (enemies are not solid)
    var _dx = hsp;
    var _sx = sign(_dx);
    var _n = ceil(abs(_dx));
    repeat (_n) {
        if (_sx == 0) break;
        var _nx = x + _sx;
        var _blocked = place_meeting(_nx, y, obj_solid) || place_meeting(_nx, y, obj_wall);
        if (!_blocked && _tm != noone && _tm != -1) {
            _blocked = tilemap_point_solid(_tm, _nx, y)
                || tilemap_point_solid(_tm, _nx, bbox_top + 4)
                || tilemap_point_solid(_tm, _nx, bbox_bottom - 4);
        }
        if (_blocked) {
            hsp = 0;
            break;
        }
        x = _nx;
    }

    // Vertical
    var _dy = vsp;
    var _sy = sign(_dy);
    _n = ceil(abs(_dy));
    repeat (_n) {
        if (_sy == 0) break;
        var _ny = y + _sy;
        var _blocked_y = place_meeting(x, _ny, obj_solid) || place_meeting(x, _ny, obj_wall);
        if (!_blocked_y && _tm != noone && _tm != -1) {
            if (_sy > 0) {
                _blocked_y = tilemap_point_solid(_tm, x, bbox_bottom + 1)
                    || tilemap_point_solid(_tm, bbox_left + 2, bbox_bottom + 1)
                    || tilemap_point_solid(_tm, bbox_right - 2, bbox_bottom + 1);
            } else {
                _blocked_y = tilemap_point_solid(_tm, x, bbox_top - 1)
                    || tilemap_point_solid(_tm, bbox_left + 2, bbox_top - 1)
                    || tilemap_point_solid(_tm, bbox_right - 2, bbox_top - 1);
            }
        }
        if (_blocked_y) {
            vsp = 0;
            break;
        }
        y = _ny;
    }

    hsp *= _decay;
}

/// @function scr_player_perfect_dodge_spawn_ghost
function scr_player_perfect_dodge_spawn_ghost() {
    var _g = instance_create_depth(x, y, depth + 1, obj_player_ghost);
    _g.sprite_index = sprite_index;
    _g.image_index = image_index;
    _g.image_xscale = image_xscale;
    _g.image_yscale = image_yscale;
}

/// @function scr_player_perfect_dodge_slowmo_step
/// @description Window: flip hop, ghosts, listen for attack, expire → free.
function scr_player_perfect_dodge_slowmo_step() {
    perfect_dodge_timer--;

    // Build Bulb slow-mo lighting toward full focus
    if (variable_instance_exists(id, "perfect_dodge_light_t")) {
        perfect_dodge_light_t = min(1, perfect_dodge_light_t + 0.16);
    }

    // Scrub double-jump flip across the window
    var _max = max(1, perfect_dodge_window_max);
    var _u = 1 - (perfect_dodge_timer / _max);
    var _frames = max(1, sprite_get_number(spr_mc_doublejump));
    sprite_index = spr_mc_doublejump;
    image_index = clamp(_u * (_frames - 0.01), 0, _frames - 0.01);
    image_speed = 0;
    image_blend = merge_color(c_white, make_color_rgb(160, 210, 255), 0.35);

    scr_player_perfect_dodge_apply_flip_motion();

    // Afterimage every 2–3 frames
    var _ghost_every = variable_instance_exists(id, "PERFECT_DODGE_GHOST_INTERVAL")
        ? PERFECT_DODGE_GHOST_INTERVAL : 2;
    perfect_dodge_ghost_tick++;
    if (perfect_dodge_ghost_tick >= _ghost_every) {
        perfect_dodge_ghost_tick = 0;
        scr_player_perfect_dodge_spawn_ghost();
    }

    if (key_attack) {
        scr_player_begin_dodge_counter();
        return;
    }

    if (perfect_dodge_timer <= 0) {
        scr_player_perfect_dodge_end_slowmo();
    }
}

/// @function scr_player_perfect_dodge_spawn_focus_distort
/// @description Icy distortion + expanding glow circle (enemy hit-react pipeline, cyan tint).
function scr_player_perfect_dodge_spawn_focus_distort(_strength = 1.25) {
    var _ice = make_colour_rgb(140, 220, 255);
    var _py = y + (variable_instance_exists(id, "BULB_PLAYER_TORCH_Y_OFFSET")
        ? BULB_PLAYER_TORCH_Y_OFFSET : -12);
    // Primary expanding ring
    scr_hit_distort_add(x, _py, _strength, _ice);
    // Soft outer echo — same effect language as multi-hit enemy glow
    scr_hit_distort_add(x, _py, _strength * 0.72, make_colour_rgb(100, 190, 255));
}

/// @function scr_player_perfect_dodge_lighting_step
/// @description Bulb slow-mo focus: crush cave ambient, ice the player torch;
///              blue focus circle forms only after the distort ring finishes.
function scr_player_perfect_dodge_lighting_step() {
    if (!variable_instance_exists(id, "perfect_dodge_light_t")) perfect_dodge_light_t = 0;
    if (!variable_instance_exists(id, "perfect_dodge_aura_timer")) perfect_dodge_aura_timer = 0;

    var _want = (state == PLAYER_STATE.PERFECT_DODGE_SLOWMO) ? 1 : 0;
    var _rate = (_want > perfect_dodge_light_t) ? 0.16 : 0.1;
    perfect_dodge_light_t = lerp(perfect_dodge_light_t, _want, _rate);
    if (abs(perfect_dodge_light_t - _want) < 0.01) perfect_dodge_light_t = _want;

    var _t = clamp(perfect_dodge_light_t, 0, 1);
    var _ease = _t * _t * (3 - 2 * _t);

    // Count down until the expanding distort finishes, then allow the settled blue circle
    if (perfect_dodge_aura_timer > 0) {
        perfect_dodge_aura_timer--;
    }

    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        var _ar = lerp(BULB_AMBIENT_R, variable_instance_exists(id, "PERFECT_DODGE_LIGHT_AMB_R")
            ? PERFECT_DODGE_LIGHT_AMB_R : 3, _ease);
        var _ag = lerp(BULB_AMBIENT_G, variable_instance_exists(id, "PERFECT_DODGE_LIGHT_AMB_G")
            ? PERFECT_DODGE_LIGHT_AMB_G : 5, _ease);
        var _ab = lerp(BULB_AMBIENT_B, variable_instance_exists(id, "PERFECT_DODGE_LIGHT_AMB_B")
            ? PERFECT_DODGE_LIGHT_AMB_B : 12, _ease);
        global.bulb_renderer.ambientColor = make_colour_rgb(_ar, _ag, _ab);
    }

    // Player torch — icy focus while slow-mo is active
    if (_ease > 0.01 && BULB_PLAYER_TORCH_ENABLED
        && variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        var _torch_warm = make_colour_rgb(255, 235, 190);
        var _torch_ice = make_colour_rgb(150, 230, 255);
        var _int_s = variable_instance_exists(id, "PERFECT_DODGE_LIGHT_TORCH_INTENSITY")
            ? PERFECT_DODGE_LIGHT_TORCH_INTENSITY : 2.15;
        var _sc_s = variable_instance_exists(id, "PERFECT_DODGE_LIGHT_TORCH_SCALE")
            ? PERFECT_DODGE_LIGHT_TORCH_SCALE : 2.05;

        if (bulb_light == undefined) {
            bulb_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
            bulb_light.penumbraSize = 0;
            bulb_light.castShadows = false;
            bulb_light.normalMap = global.bulb_normal_maps_enabled;
            bulb_light.normalMapZ = 40;
        }

        bulb_light.visible = true;
        bulb_light.x = x;
        bulb_light.y = y + BULB_PLAYER_TORCH_Y_OFFSET;
        bulb_light.normalMap = global.bulb_normal_maps_enabled;
        bulb_light.blend = merge_colour(_torch_warm, _torch_ice, _ease);
        bulb_light.intensity = lerp(BULB_PLAYER_TORCH_INTENSITY, _int_s, _ease);
        var _sc = lerp(BULB_PLAYER_TORCH_SCALE, _sc_s, _ease);
        bulb_light.xscale = _sc;
        bulb_light.yscale = _sc;
    }

    // Blue focus circle — only after distort life ends, then bloom in as a settled ring
    var _aura_ready = (perfect_dodge_aura_timer <= 0) && (_ease > 0.15)
        && variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined;

    if (_aura_ready) {
        var _fi = variable_instance_exists(id, "PERFECT_DODGE_LIGHT_FOCUS_INTENSITY")
            ? PERFECT_DODGE_LIGHT_FOCUS_INTENSITY : 1.35;
        var _fs = variable_instance_exists(id, "PERFECT_DODGE_LIGHT_FOCUS_SCALE")
            ? PERFECT_DODGE_LIGHT_FOCUS_SCALE : 3.4;

        if (perfect_dodge_focus_light == undefined) {
            perfect_dodge_focus_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
            perfect_dodge_focus_light.penumbraSize = 0;
            perfect_dodge_focus_light.castShadows = false;
            perfect_dodge_focus_light.normalMap = global.bulb_normal_maps_enabled;
            perfect_dodge_focus_light.normalMapZ = 55;
            perfect_dodge_focus_light.blend = make_colour_rgb(120, 200, 255);
            // Start small — expands into the settled circle the distort left behind
            perfect_dodge_focus_light.xscale = _fs * 0.35;
            perfect_dodge_focus_light.yscale = _fs * 0.35;
            perfect_dodge_focus_light.intensity = 0;
        }

        perfect_dodge_focus_light.visible = true;
        perfect_dodge_focus_light.x = x;
        perfect_dodge_focus_light.y = y + BULB_PLAYER_TORCH_Y_OFFSET;
        perfect_dodge_focus_light.normalMap = global.bulb_normal_maps_enabled;
        // Soft form-up: scale + intensity ease toward full aura
        perfect_dodge_focus_light.xscale = lerp(perfect_dodge_focus_light.xscale, _fs, 0.12);
        perfect_dodge_focus_light.yscale = perfect_dodge_focus_light.xscale;
        perfect_dodge_focus_light.intensity = lerp(perfect_dodge_focus_light.intensity, _fi * _ease, 0.14);
    } else if (perfect_dodge_focus_light != undefined) {
        // Fade the circle out if slow-mo ends, or keep waiting while timer runs
        if (_ease < 0.05) {
            perfect_dodge_focus_light.Destroy();
            perfect_dodge_focus_light = undefined;
            perfect_dodge_distort_fired = false;
        } else if (perfect_dodge_aura_timer > 0) {
            // Distort still expanding — no settled circle yet
            perfect_dodge_focus_light.visible = false;
        }
    }
}

/// @function scr_player_perfect_dodge_fx_draw
/// @description Ghosts + shing flare above the lit scene so they stay bright.
function scr_player_perfect_dodge_fx_draw() {
    with (obj_player_ghost) {
        event_perform(ev_draw, 0);
    }
    with (obj_dodge_shing_flare) {
        event_perform(ev_draw, 0);
    }
    // Keep the player readable on top of the darken
    if (instance_exists(obj_player)) {
        with (obj_player) {
            if (state == PLAYER_STATE.PERFECT_DODGE_SLOWMO) {
                draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
                    image_xscale, image_yscale, 0, image_blend, 1);
            } else if (state == PLAYER_STATE.DODGE_COUNTER) {
                if (variable_instance_exists(id, "dodge_counter_hidden") && dodge_counter_hidden) {
                    scr_player_dodge_counter_draw_flurry();
                } else if (image_alpha > 0.02) {
                    draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
                        image_xscale, image_yscale, 0, image_blend, image_alpha);
                }
            }
        }
    }
}
