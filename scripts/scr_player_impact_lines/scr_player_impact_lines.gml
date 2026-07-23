/// @file scr_player_impact_lines.gml
/// Hit juice spawn API — creates obj_hit_slash + obj_hit_particle (Celeste / HK style).

/// @function scr_hit_fx_layer
/// @description Prefer a Particles layer when present; otherwise Instances.
function scr_hit_fx_layer() {
    if (layer_exists("Particles")) return "Particles";
    return "Instances";
}

/// @function scr_hit_slash_burst_debris
/// @description Spawn blocky debris + fast axis sparks (call AFTER slash_angle is set).
function scr_hit_slash_burst_debris(_glow = c_aqua, _finisher = false) {
    var _layer = scr_hit_fx_layer();

    // Chunky debris — spread across the swing arc
    var _chunks = _finisher ? irandom_range(11, 15) : irandom_range(8, 12);
    repeat (_chunks) {
        var _offset = random_range(-12, 12);
        var _px = x + lengthdir_x(_offset, slash_angle);
        var _py = y + lengthdir_y(_offset, slash_angle);

        var _p = instance_create_layer(_px, _py, _layer, obj_hit_particle);
        _p.direction = slash_angle + random_range(-40, 40);
        _p.speed = random_range(4, 9);
        _p.glow_col = _glow;
        // A few bright cyan chunks for color pop
        _p.col = (irandom(3) == 0) ? _glow : c_white;
    }

    // Fast long sparks streaking along the swing axis (both ways)
    repeat (_finisher ? irandom_range(3, 5) : irandom_range(2, 3)) {
        var _sp = instance_create_layer(x, y, _layer, obj_hit_particle);
        _sp.direction = slash_angle + choose(0, 180) + random_range(-8, 8);
        _sp.speed = random_range(9, 15);
        _sp.size = irandom_range(1, 2);
        _sp.life_max = irandom_range(6, 11);
        _sp.life = _sp.life_max;
        _sp.glow_col = _glow;
        _sp.col = c_white;
    }
}

/// @function scr_hit_slash_create
/// @description Spawn one razor slash at world coords; optionally burst debris.
function scr_hit_slash_create(_x, _y, _angle, _length = 56, _color_outer = c_aqua, _life = 7, _burst = true, _finisher = false) {
    var _layer = scr_hit_fx_layer();
    var _s = instance_create_layer(_x, _y, _layer, obj_hit_slash);
    _s.slash_angle = _angle;
    _s.slash_length = _length;
    _s.color_outer = _color_outer;
    _s.color_inner = c_white;
    _s.life_max = _life;
    _s.life_timer = _life;
    if (_burst) {
        with (_s) {
            scr_hit_slash_burst_debris(_color_outer, _finisher);
        }
    }
    return _s;
}

/// @function scr_player_impact_lines_clear
function scr_player_impact_lines_clear() {
    // Legacy no-op — slash/particles self-destroy.
}

/// @function scr_player_impact_lines_step
function scr_player_impact_lines_step() {
    // Legacy no-op — objects tick themselves.
}

/// @function scr_player_impact_lines_draw
/// @description Draw all hit FX after Bulb glow (objects stay visible=false in room draw).
function scr_player_impact_lines_draw() {
    with (obj_hit_slash) {
        event_perform(ev_draw, 0);
    }
    with (obj_hit_particle) {
        event_perform(ev_draw, 0);
    }
}

/// @function scr_player_attack_impact_sfx
/// @description Random clank with pitch variation, played through the cave reverb bus.
function scr_player_attack_impact_sfx(_finisher = false) {
    var _clanks = [snd_clank_1, snd_clank_2, snd_clank_3];

    // Avoid repeating the same clip back-to-back
    var _pick = irandom(array_length(_clanks) - 1);
    if (variable_instance_exists(id, "attack_clank_last")
        && _pick == attack_clank_last && random(1) < 0.7) {
        _pick = (_pick + 1 + irandom(1)) mod array_length(_clanks);
    }
    attack_clank_last = _pick;

    var _pitch_lo = (variable_instance_exists(id, "ATTACK_IMPACT_PITCH_MIN") ? ATTACK_IMPACT_PITCH_MIN : 0.86);
    var _pitch_hi = (variable_instance_exists(id, "ATTACK_IMPACT_PITCH_MAX") ? ATTACK_IMPACT_PITCH_MAX : 1.12);
    var _gain     = (variable_instance_exists(id, "ATTACK_IMPACT_GAIN") ? ATTACK_IMPACT_GAIN : 0.9);

    var _pitch = random_range(_pitch_lo, _pitch_hi);
    if (_finisher) {
        _pitch *= 0.85; // Beefier, lower clank on finishers
        _gain  *= 1.15;
    }

    var _prio = 12;
    if (variable_global_exists("sfx_combat_emitter")) {
        // audio_play_sound_on(emitter, sound, loop, priority, gain, offset, pitch)
        return audio_play_sound_on(global.sfx_combat_emitter, _clanks[_pick], false, _prio, _gain, 0, _pitch);
    }

    var _snd_id = audio_play_sound(_clanks[_pick], _prio, false);
    if (_snd_id != -1) {
        audio_sound_pitch(_snd_id, _pitch);
        audio_sound_gain(_snd_id, _gain, 0);
    }
    return _snd_id;
}

/// @function scr_player_impact_lines_on_hit
/// @description Spawn directional slash FX aligned to the attack angle.
function scr_player_impact_lines_on_hit(_x1, _y1, _x2, _y2, _enemy = noone, _skip_sfx = false) {
    var _cx = (_x1 + _x2) * 0.5;
    var _cy = (_y1 + _y2) * 0.5;
    if (_enemy != noone && instance_exists(_enemy)) {
        _cx = lerp(_cx, _enemy.x, 0.55);
        _cy = lerp(_cy, (_enemy.bbox_top + _enemy.bbox_bottom) * 0.5, 0.55);
    }

    var _finisher = (comboCount >= 2);

    // Cave-reverb clank with randomized pitch (once per landed hit)
    if (!_skip_sfx) {
        scr_player_attack_impact_sfx(_finisher);
    }

    var _angle;

    // Align to attack vector — downward air strike vs facing slash
    if (scr_player_is_downward_air_strike()) {
        _angle = 270; // straight down
    } else {
        var _face = (last_direction != 0) ? last_direction : sign(image_xscale);
        if (_face == 0) _face = 1;
        // Facing axis + slight down-forward tilt (reads as a slash, not a flat beam)
        _angle = (_face >= 0) ? 0 : 180;
        _angle += _face * -18;
    }

    var _len = _finisher ? 104 : 78;
    var _life = _finisher ? 9 : 7;
    var _col = _finisher ? make_colour_rgb(140, 255, 255) : c_aqua;

    // Primary razor slash + debris burst
    scr_hit_slash_create(_cx, _cy, _angle, _len, _col, _life, true, _finisher);

    // Companion secondary slash — layered punch, no extra debris
    var _ang2 = _angle + random_range(-16, 16);
    scr_hit_slash_create(
        _cx + lengthdir_x(3, _ang2 + 90),
        _cy + lengthdir_y(3, _ang2 + 90),
        _ang2,
        _len * 0.68,
        _col,
        max(5, _life - 2),
        false,
        _finisher
    );

    // Cross-flash slash for finishers — perpendicular accent (extra impact)
    if (_finisher) {
        scr_hit_slash_create(_cx, _cy, _angle + 90, _len * 0.5, c_white, 6, false, false);
    }
}
