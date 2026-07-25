/// @file scr_player_footsteps.gml
/// @description Animation-synced cave footsteps — contact frames, clip variety, speed-scaled pitch/volume.

/// @function scr_player_footsteps_crossed_frame
/// @description True when image_index advanced past _frame this Step (handles anim loop).
function scr_player_footsteps_crossed_frame(_prev, _curr, _frame) {
    if (_curr >= _prev) {
        return (_prev < _frame && _curr >= _frame);
    }
    return (_frame > _prev || _curr >= _frame);
}

/// @function scr_player_footsteps_contact_frames_for_sprite
/// @returns {Array<Real>} Foot-down frames for the current locomotion sprite.
function scr_player_footsteps_contact_frames_for_sprite(_spr) {
    if (_spr == spr_mc_sprint) {
        return (variable_instance_exists(id, "FOOTSTEP_SPRINT_CONTACT_FRAMES")
            ? FOOTSTEP_SPRINT_CONTACT_FRAMES : [2, 6]);
    }
    if (_spr == spr_mc_jog) {
        return (variable_instance_exists(id, "FOOTSTEP_JOG_CONTACT_FRAMES")
            ? FOOTSTEP_JOG_CONTACT_FRAMES : [2, 6]);
    }
    if (_spr == spr_mc_reelback) {
        return (variable_instance_exists(id, "FOOTSTEP_REELBACK_CONTACT_FRAMES")
            ? FOOTSTEP_REELBACK_CONTACT_FRAMES : [1, 2]);
    }
    return [];
}

/// @function scr_player_footsteps_speed_norm
/// @returns {Real} 0..1 locomotion intensity from horizontal speed (jog → sprint).
function scr_player_footsteps_speed_norm() {
    var _thresh = (variable_instance_exists(id, "MOVEMENT_THRESHOLD") ? MOVEMENT_THRESHOLD : 0.5);
    var _top = (variable_instance_exists(id, "runsp") ? runsp : 5);
    return clamp((abs(hsp) - _thresh) / max(0.01, _top - _thresh), 0, 1);
}

/// @function scr_player_footstep_play_cave
/// @param {Real} [_speed_norm] 0..1 — scales pitch and volume with jog/sprint speed.
function scr_player_footstep_play_cave(_speed_norm) {
    if (argument_count < 1) _speed_norm = scr_player_footsteps_speed_norm();

    var _sounds = [
        snd_cave_footstep1,
        snd_cave_footstep2,
        snd_cave_footstep3
    ];

    var _pick = irandom(array_length(_sounds) - 1);
    if (variable_instance_exists(id, "footstep_last_clip")
        && _pick == footstep_last_clip && random(1) < 0.7) {
        _pick = (_pick + 1 + irandom(1)) mod array_length(_sounds);
    }
    footstep_last_clip = _pick;

    var _pitch_lo = (variable_instance_exists(id, "FOOTSTEP_PITCH_MIN") ? FOOTSTEP_PITCH_MIN : 0.50);
    var _pitch_hi = (variable_instance_exists(id, "FOOTSTEP_PITCH_MAX") ? FOOTSTEP_PITCH_MAX : 0.70);
    var _pitch_jit = (variable_instance_exists(id, "FOOTSTEP_PITCH_JITTER") ? FOOTSTEP_PITCH_JITTER : 0.03);
    var _pitch_cave = (variable_instance_exists(id, "FOOTSTEP_PITCH_CAVE") ? FOOTSTEP_PITCH_CAVE : 0.76);
    var _pitch_bias = (variable_instance_exists(id, "FOOTSTEP_PITCH_BIAS") ? FOOTSTEP_PITCH_BIAS : 1.5);

    var _vol_lo = (variable_instance_exists(id, "FOOTSTEP_VOL_MIN") ? FOOTSTEP_VOL_MIN : 0.20);
    var _vol_hi = (variable_instance_exists(id, "FOOTSTEP_VOL_MAX") ? FOOTSTEP_VOL_MAX : 0.38);
    var _vol_cave = (variable_instance_exists(id, "FOOTSTEP_VOL_CAVE") ? FOOTSTEP_VOL_CAVE : 0.88);

    // Skew pitch low — distant cave steps read deeper and softer (same trick as drip SFX).
    var _pitch_t = power(random(1), _pitch_bias);
    var _pitch = lerp(_pitch_lo, _pitch_hi, _pitch_t) * _pitch_cave
        * random_range(1 - _pitch_jit, 1 + _pitch_jit);
    var _gain = lerp(_vol_lo, _vol_hi, _speed_norm) * _vol_cave * random_range(0.9, 1.0);

    var _bus = (variable_instance_exists(id, "FOOTSTEP_AUDIO_PRIORITY") ? FOOTSTEP_AUDIO_PRIORITY : 8);
    // Route through the shared cave reverb bus so steps echo like the rest of the cavern.
    if (variable_global_exists("sfx_cave_emitter")) {
        audio_play_sound_on(global.sfx_cave_emitter, _sounds[_pick], false, _bus, _gain, 0, _pitch);
    } else {
        var _snd_id = audio_play_sound(_sounds[_pick], _bus, false);
        if (_snd_id != -1) {
            audio_sound_pitch(_snd_id, _pitch);
            audio_sound_gain(_snd_id, _gain, 0);
        }
    }
}

/// @function scr_player_footstep_play_armor
/// @description Soft chainmail bed under a footfall — quieter than the cave step, scales with speed.
/// @param {Real} [_speed_norm] 0..1 jog→sprint
/// @param {Bool} [_land] Landing layer (slightly fuller rustle)
function scr_player_footstep_play_armor(_speed_norm, _land = false) {
    if (variable_instance_exists(id, "FOOTSTEP_ARMOR_ENABLED") && !FOOTSTEP_ARMOR_ENABLED) return;

    if (argument_count < 1) _speed_norm = scr_player_footsteps_speed_norm();

    // Not every jog step — sprint denser so armor reads with pace
    var _chance_lo = (variable_instance_exists(id, "FOOTSTEP_ARMOR_CHANCE_JOG")
        ? FOOTSTEP_ARMOR_CHANCE_JOG : 0.72);
    var _chance_hi = (variable_instance_exists(id, "FOOTSTEP_ARMOR_CHANCE_SPRINT")
        ? FOOTSTEP_ARMOR_CHANCE_SPRINT : 0.95);
    var _chance = _land ? 1 : lerp(_chance_lo, _chance_hi, _speed_norm);
    if (random(1) > _chance) return;

    var _clips = [
        snd_chainmail_1, snd_chainmail_2, snd_chainmail_3,
        snd_chainmail_4, snd_chainmail_5, snd_chainmail_6
    ];
    var _pick = irandom(array_length(_clips) - 1);
    if (variable_instance_exists(id, "footstep_armor_last")
        && _pick == footstep_armor_last && random(1) < 0.75) {
        _pick = (_pick + 1 + irandom(2)) mod array_length(_clips);
    }
    footstep_armor_last = _pick;

    var _pitch_lo = (variable_instance_exists(id, "FOOTSTEP_ARMOR_PITCH_MIN")
        ? FOOTSTEP_ARMOR_PITCH_MIN : 1.05);
    var _pitch_hi = (variable_instance_exists(id, "FOOTSTEP_ARMOR_PITCH_MAX")
        ? FOOTSTEP_ARMOR_PITCH_MAX : 1.28);
    var _vol_lo = (variable_instance_exists(id, "FOOTSTEP_ARMOR_VOL_MIN")
        ? FOOTSTEP_ARMOR_VOL_MIN : 0.18);
    var _vol_hi = (variable_instance_exists(id, "FOOTSTEP_ARMOR_VOL_MAX")
        ? FOOTSTEP_ARMOR_VOL_MAX : 0.34);

    // Brighter / quieter than jump-dash whoosh — sits under the stone thud
    var _pitch = random_range(_pitch_lo, _pitch_hi);
    var _gain = lerp(_vol_lo, _vol_hi, _speed_norm) * random_range(0.88, 1.05);
    if (_land) {
        _pitch *= 0.92;
        _gain  *= 1.25;
    }

    var _prio = (variable_instance_exists(id, "FOOTSTEP_AUDIO_PRIORITY")
        ? max(1, FOOTSTEP_AUDIO_PRIORITY - 1) : 7);

    if (variable_global_exists("sfx_cave_emitter")) {
        audio_play_sound_on(global.sfx_cave_emitter, _clips[_pick], false, _prio, _gain, 0, _pitch);
    } else {
        var _snd_id = audio_play_sound(_clips[_pick], _prio, false);
        if (_snd_id != -1) {
            audio_sound_pitch(_snd_id, _pitch);
            audio_sound_gain(_snd_id, _gain, 0);
        }
    }
}

/// @function scr_player_whoosh_sfx
/// @description Shared armor rustle (sliced from snd_chainmail_chunks) — jump, dash, Perfect Dodge.
/// @param {Bool} [_heavy] Double jump / Perfect Dodge — slightly lower + louder.
function scr_player_whoosh_sfx(_heavy = false) {
    var _clips = [
        snd_chainmail_1, snd_chainmail_2, snd_chainmail_3,
        snd_chainmail_4, snd_chainmail_5, snd_chainmail_6
    ];

    // Avoid repeating the same clip back-to-back (shared across jump / dash / PD)
    var _pick = irandom(array_length(_clips) - 1);
    if (variable_instance_exists(id, "jump_sfx_last")
        && _pick == jump_sfx_last && random(1) < 0.7) {
        _pick = (_pick + 1 + irandom(2)) mod array_length(_clips);
    }
    jump_sfx_last = _pick;

    var _pitch_lo = (variable_instance_exists(id, "JUMP_SFX_PITCH_MIN") ? JUMP_SFX_PITCH_MIN : 0.88);
    var _pitch_hi = (variable_instance_exists(id, "JUMP_SFX_PITCH_MAX") ? JUMP_SFX_PITCH_MAX : 1.14);
    var _gain     = (variable_instance_exists(id, "JUMP_SFX_GAIN") ? JUMP_SFX_GAIN : 0.85);

    var _pitch = random_range(_pitch_lo, _pitch_hi);
    if (_heavy) {
        _pitch *= 0.9;
        _gain  *= 1.1;
    }

    var _prio = 11;
    // Same cavern reverb as footstep armor / cave steps (not the combat hit bus)
    if (variable_global_exists("sfx_cave_emitter")) {
        return audio_play_sound_on(global.sfx_cave_emitter, _clips[_pick], false, _prio, _gain, 0, _pitch);
    }
    if (variable_global_exists("sfx_combat_emitter")) {
        return audio_play_sound_on(global.sfx_combat_emitter, _clips[_pick], false, _prio, _gain, 0, _pitch);
    }

    var _snd_id = audio_play_sound(_clips[_pick], _prio, false);
    if (_snd_id != -1) {
        audio_sound_pitch(_snd_id, _pitch);
        audio_sound_gain(_snd_id, _gain, 0);
    }
    return _snd_id;
}

/// @function scr_player_jump_sfx
/// @description Jump / double-jump whoosh wrapper.
/// @param {Bool} [_double_jump]
function scr_player_jump_sfx(_double_jump = false) {
    return scr_player_whoosh_sfx(_double_jump);
}

/// @function scr_player_perfect_dodge_sfx
/// @description Perfect Dodge air-flip parry — pitch variety, same bus pattern as swings/whoosh.
function scr_player_perfect_dodge_sfx() {
    var _snd = snd_air_flip_parry;
    var _pitch_lo = (variable_instance_exists(id, "PERFECT_DODGE_SFX_PITCH_MIN")
        ? PERFECT_DODGE_SFX_PITCH_MIN : 0.88);
    var _pitch_hi = (variable_instance_exists(id, "PERFECT_DODGE_SFX_PITCH_MAX")
        ? PERFECT_DODGE_SFX_PITCH_MAX : 1.14);
    var _gain = (variable_instance_exists(id, "PERFECT_DODGE_SFX_GAIN")
        ? PERFECT_DODGE_SFX_GAIN : 0.9);
    var _pitch = random_range(_pitch_lo, _pitch_hi);
    var _prio = 12;

    if (variable_global_exists("sfx_combat_emitter")) {
        return audio_play_sound_on(global.sfx_combat_emitter, _snd, false, _prio, _gain, 0, _pitch);
    }
    if (variable_global_exists("sfx_cave_emitter")) {
        return audio_play_sound_on(global.sfx_cave_emitter, _snd, false, _prio, _gain, 0, _pitch);
    }

    var _snd_id = audio_play_sound(_snd, _prio, false);
    if (_snd_id != -1) {
        audio_sound_pitch(_snd_id, _pitch);
        audio_sound_gain(_snd_id, _gain, 0);
    }
    return _snd_id;
}

/// @function scr_player_footstep_play_land
/// @param {Real} _impact_vsp Downward speed on the frame before touchdown (scales pitch/volume).
function scr_player_footstep_play_land(_impact_vsp) {
    var _snd = (variable_instance_exists(id, "FOOTSTEP_LAND_SOUND") ? FOOTSTEP_LAND_SOUND : snd_cave_footstep1);
    var _ref = (variable_instance_exists(id, "LAND_SOUND_VSP_REF") ? LAND_SOUND_VSP_REF : 8);
    var _impact_norm = clamp(_impact_vsp / max(0.01, _ref), 0.25, 1);

    var _pitch_lo = (variable_instance_exists(id, "FOOTSTEP_LAND_PITCH_MIN") ? FOOTSTEP_LAND_PITCH_MIN : 0.44);
    var _pitch_hi = (variable_instance_exists(id, "FOOTSTEP_LAND_PITCH_MAX") ? FOOTSTEP_LAND_PITCH_MAX : 0.58);
    var _pitch_cave = (variable_instance_exists(id, "FOOTSTEP_LAND_PITCH_CAVE") ? FOOTSTEP_LAND_PITCH_CAVE : 0.74);
    var _vol_lo = (variable_instance_exists(id, "FOOTSTEP_LAND_VOL_MIN") ? FOOTSTEP_LAND_VOL_MIN : 0.28);
    var _vol_hi = (variable_instance_exists(id, "FOOTSTEP_LAND_VOL_MAX") ? FOOTSTEP_LAND_VOL_MAX : 0.48);
    var _vol_cave = (variable_instance_exists(id, "FOOTSTEP_VOL_CAVE") ? FOOTSTEP_VOL_CAVE : 0.88);
    var _pitch_bias = (variable_instance_exists(id, "FOOTSTEP_PITCH_BIAS") ? FOOTSTEP_PITCH_BIAS : 1.5);

    var _pitch_t = power(random(1), _pitch_bias);
    var _pitch = lerp(_pitch_lo, _pitch_hi, _pitch_t) * _pitch_cave * random_range(0.96, 1.02);
    var _gain = lerp(_vol_lo, _vol_hi, _impact_norm) * _vol_cave * random_range(0.9, 1.0);

    var _bus = (variable_instance_exists(id, "FOOTSTEP_AUDIO_PRIORITY") ? FOOTSTEP_AUDIO_PRIORITY : 8);
    // Route through the shared cave reverb bus so the landing thud echoes.
    if (variable_global_exists("sfx_cave_emitter")) {
        audio_play_sound_on(global.sfx_cave_emitter, _snd, false, _bus, _gain, 0, _pitch);
    } else {
        var _snd_id = audio_play_sound(_snd, _bus, false);
        if (_snd_id != -1) {
            audio_sound_pitch(_snd_id, _pitch);
            audio_sound_gain(_snd_id, _gain, 0);
        }
    }
}

/// @function scr_player_footsteps_land_check
/// @description Play land thud when transitioning airborne → grounded after a real fall.
function scr_player_footsteps_land_check() {
    if (global.hitstop > 0) return;

    var _was_grounded = (variable_instance_exists(id, "footstep_was_grounded") ? footstep_was_grounded : true);
    var _jumped = (variable_instance_exists(id, "jumped_this_frame") ? jumped_this_frame : false);
    var _landed = (!_was_grounded && grounded && !_jumped && stunTimer <= 0);

    if (_landed) {
        var _min_vsp = (variable_instance_exists(id, "LAND_SOUND_MIN_VSP") ? LAND_SOUND_MIN_VSP : 2.5);
        var _min_air = (variable_instance_exists(id, "LAND_SOUND_MIN_AIR_FRAMES") ? LAND_SOUND_MIN_AIR_FRAMES : 4);
        var _fall_vsp = (variable_instance_exists(id, "footstep_fall_vsp") ? footstep_fall_vsp : 0);
        var _air_frames = (variable_instance_exists(id, "footstep_airborne_frames") ? footstep_airborne_frames : 0);

        if (_fall_vsp >= _min_vsp && _air_frames >= _min_air) {
            if (variable_instance_exists(id, "FOOTSTEP_CAVE_ENABLED") ? FOOTSTEP_CAVE_ENABLED : true) {
                scr_player_footstep_play_land(_fall_vsp);
                // Soft armor settle under the land thud
                var _land_norm = clamp(_fall_vsp / max(0.01,
                    (variable_instance_exists(id, "LAND_SOUND_VSP_REF") ? LAND_SOUND_VSP_REF : 8)), 0.35, 1);
                scr_player_footstep_play_armor(_land_norm, true);
            }
            if (variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true) {
                scr_player_ground_debris_on_land(_fall_vsp);
            }
            var _land_cd = (variable_instance_exists(id, "FOOTSTEP_LAND_STEP_COOLDOWN") ? FOOTSTEP_LAND_STEP_COOLDOWN : 8);
            footstep_cooldown = max((variable_instance_exists(id, "footstep_cooldown") ? footstep_cooldown : 0), _land_cd);
        }

        // Landing squash even on lighter drops (uses its own min vsp / air frames).
        var _sq_air = (variable_instance_exists(id, "LAND_SQUASH_MIN_AIR_FRAMES") ? LAND_SQUASH_MIN_AIR_FRAMES : 3);
        if (_air_frames >= _sq_air) {
            scr_player_land_squash_trigger(_fall_vsp);
        }
    }

    if (grounded) {
        footstep_was_grounded = true;
        footstep_fall_vsp = 0;
        footstep_airborne_frames = 0;
    } else {
        footstep_was_grounded = false;
        if (vsp > 0) {
            footstep_fall_vsp = max((variable_instance_exists(id, "footstep_fall_vsp") ? footstep_fall_vsp : 0), vsp);
        }
        footstep_airborne_frames = (variable_instance_exists(id, "footstep_airborne_frames") ? footstep_airborne_frames : 0) + 1;
    }
}

/// @function scr_player_footsteps_step
/// @description Call once per Step after movement/animation — land thud + jog contact steps.
function scr_player_footsteps_step() {
    scr_player_footsteps_land_check();

    if (global.hitstop > 0) return;

    var _sfx_on = (variable_instance_exists(id, "FOOTSTEP_CAVE_ENABLED") ? FOOTSTEP_CAVE_ENABLED : true);
    var _debris_on = (variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true);
    if (!_sfx_on && !_debris_on) return;

    if (!grounded || stunTimer > 0 || attacking) return;
    if (sprite_index != spr_mc_reelback && abs(hsp) < MOVEMENT_THRESHOLD) return;
    if (sprite_index != spr_mc_jog && sprite_index != spr_mc_sprint && sprite_index != spr_mc_reelback) return;

    if (!variable_instance_exists(id, "footstep_track_sprite") || footstep_track_sprite != sprite_index) {
        footstep_track_sprite = sprite_index;
        footstep_anim_prev_index = image_index;
        return;
    }

    var _prev = footstep_anim_prev_index;
    var _curr = image_index;
    var _contacts = scr_player_footsteps_contact_frames_for_sprite(sprite_index);
    var _triggered = false;

    for (var _i = 0; _i < array_length(_contacts); _i++) {
        if (scr_player_footsteps_crossed_frame(_prev, _curr, _contacts[_i])) {
            _triggered = true;
            break;
        }
    }

    footstep_anim_prev_index = _curr;

    if (!_triggered) return;

    var _min_gap = (variable_instance_exists(id, "FOOTSTEP_MIN_INTERVAL") ? FOOTSTEP_MIN_INTERVAL : 4);
    if (variable_instance_exists(id, "footstep_cooldown") && footstep_cooldown > 0) return;

    var _speed_norm = scr_player_footsteps_speed_norm();

    if (_sfx_on) {
        if (sprite_index == spr_mc_reelback) {
            // Skid: chainmail only (no cave thud — feet aren't stepping)
            // Slightly fuller always-play rustle so the stop reads armored
            var _reel_armor = (variable_instance_exists(id, "FOOTSTEP_ARMOR_REEL_NORM")
                ? FOOTSTEP_ARMOR_REEL_NORM : 0.8);
            scr_player_footstep_play_armor(_reel_armor, true);
        } else {
            scr_player_footstep_play_cave(_speed_norm);
            scr_player_footstep_play_armor(_speed_norm, false);
        }
    }
    if (_debris_on) {
        scr_player_ground_debris_on_step_contact(_speed_norm);
    }
    footstep_cooldown = _min_gap;
}

/// @function scr_player_footsteps_cooldown_tick
function scr_player_footsteps_cooldown_tick() {
    if (variable_instance_exists(id, "footstep_cooldown") && footstep_cooldown > 0) {
        footstep_cooldown--;
    }
}
