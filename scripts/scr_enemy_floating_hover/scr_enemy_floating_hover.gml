/// @file scr_enemy_floating_hover.gml
/// @description Hover rise/fall from draw offset only — two held breath poses.
///
///   Rest: 1f | Rising: hold 8f expanded | Falling: hold 4f compressed
///   Sprite frame stays fixed per phase; hover_y_offset does the smooth rise/fall.
///
/// Create Event:  scr_enemy_floating_hover_init();
/// Step Event:    scr_enemy_floating_hover_step();

/// @function scr_enemy_floating_hover_frame_from_time
/// @param {Real} _time
/// @param {Real} _offset
/// @param {Real} _amp
/// @returns {Real}
function scr_enemy_floating_hover_frame_from_time(_time, _offset, _amp) {
    var _rest_cut = 0.04;
    var _rest = 0;          // 1f
    var _expand_hold = (variable_instance_exists(id, "hover_expand_hold")
        ? hover_expand_hold : 7);   // 8f — tall pose while rising
    var _compress_hold = (variable_instance_exists(id, "hover_compress_hold")
        ? hover_compress_hold : 3); // 4f — squat pose while falling

    var _norm = clamp(-_offset / max(0.001, 2 * _amp), 0, 1);

    if (_norm < _rest_cut) {
        return _rest;
    }

    if (cos(_time) < 0) {
        return _expand_hold;
    }

    return _compress_hold;
}

/// @function scr_enemy_floating_hover_init
function scr_enemy_floating_hover_init() {
    ystart = y;
    hover_y_offset = 0;

    hover_amplitude = 10;
    hover_breath_frame_count = sprite_get_number(sprite_index);

    hover_cycle_seconds = 3;
    hover_time_speed = (2 * pi) / (hover_cycle_seconds * max(1, room_speed));

    hover_expand_hold = 7;    // 8f while rising
    hover_compress_hold = 3;  // 4f while falling

    // Combat: ease bob down so the slash isn't stranded at peak float
    hover_attack_settle_y = 2;     // slight dip below idle rest (positive = down)
    hover_attack_settle_rate = 0.32;

    hover_time = pi * 0.5;

    image_speed = 0;
    image_index = 0;
}

/// @function scr_enemy_floating_hover_step
function scr_enemy_floating_hover_step() {
    if (variable_global_exists("hitstop") && global.hitstop > 0) {
        exit;
    }

    var _amp = (variable_instance_exists(id, "hover_amplitude") ? hover_amplitude : 10);
    var _speed = (variable_instance_exists(id, "hover_time_speed")
        ? hover_time_speed
        : (2 * pi) / ((variable_instance_exists(id, "hover_cycle_seconds") ? hover_cycle_seconds : 3) * max(1, room_speed)));

    image_speed = 0;

    // Combat poses own image_index — only apply idle breath frames on patrol/chase/stun.
    // Also settle the bob downward so attack hitboxes aren't floating above the player.
    var _hover_anim = true;
    var _combat_settle = false;
    if (variable_instance_exists(id, "state")) {
        switch (state) {
            case ENEMY_STATE.NOTICE:
            case ENEMY_STATE.TELEGRAPH:
            case ENEMY_STATE.ATTACK:
            case ENEMY_STATE.RECOIL:
                _hover_anim = false;
                _combat_settle = true;
                break;
        }
    }

    if (_combat_settle) {
        var _target = variable_instance_exists(id, "hover_attack_settle_y")
            ? hover_attack_settle_y : 0;
        var _rate = variable_instance_exists(id, "hover_attack_settle_rate")
            ? hover_attack_settle_rate : 0.32;
        hover_y_offset = lerp(hover_y_offset, _target, _rate);
        // Keep phase matched so leaving combat doesn't pop the sprite back up.
        var _s = clamp(hover_y_offset / max(0.001, _amp) + 1, -1, 1);
        hover_time = arcsin(_s);
    } else {
        hover_time += _speed;
        hover_y_offset = (sin(hover_time) - 1) * _amp;
    }

    if (_hover_anim) {
        image_index = scr_enemy_floating_hover_frame_from_time(hover_time, hover_y_offset, _amp);
    }

    if (variable_instance_exists(id, "enemy_is_floating") && enemy_is_floating) {
        y = ystart;
    }
}

/// @function scr_enemy_floating_hover_sync_anchor
function scr_enemy_floating_hover_sync_anchor() {
    if (!variable_instance_exists(id, "ystart")) return;
    ystart = y;
}

/// @function scr_enemy_floating_hover_draw_offset_y
/// @returns {Real}
function scr_enemy_floating_hover_draw_offset_y() {
    if (!variable_instance_exists(id, "hover_y_offset")) return 0;
    return hover_y_offset;
}
