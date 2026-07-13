/// @file scr_player_saber_trail.gml
/// @description Blue saber trail — particles along grip→tip blade path per swing frame.

/// @function scr_player_attack_compute_hitbox
/// @description Active swing hitbox + outer cutting edge (matches Step collision_rectangle).
/// @returns {Struct} { active, x1, y1, x2, y2, edge_x, edge_y1, edge_y2, facing, downward }
function scr_player_attack_compute_hitbox() {
    var _hb = {
        active: false,
        x1: 0, y1: 0, x2: 0, y2: 0,
        edge_x: 0, edge_y1: 0, edge_y2: 0,
        facing: 1,
        downward: false
    };

    if (!attacking) return _hb;

    var _downward = scr_player_is_downward_air_strike();
    var _start = (variable_instance_exists(id, "ATTACK_HIT_ACTIVE_START_INDEX")
        ? ATTACK_HIT_ACTIVE_START_INDEX : 1);
    var _swinging = (image_index >= _start && image_index <= 3);
    if (!_swinging && !_downward) return _hb;

    _hb.active = true;
    _hb.downward = _downward;

    var _reach = (comboCount >= 2) ? ATTACK_HITBOX_REACH_2 : ATTACK_HITBOX_REACH_1;
    var _top_pad = (comboCount >= 2) ? ATTACK_HITBOX_TOP_PAD_2 : ATTACK_HITBOX_TOP_PAD_1;
    var _bot_pad = (comboCount >= 2) ? ATTACK_HITBOX_BOT_PAD_2 : ATTACK_HITBOX_BOT_PAD_1;
    var _y1 = bbox_top + _top_pad;
    var _y2 = bbox_bottom - _bot_pad;
    var _x1;
    var _x2;

    if (_downward) {
        _x1 = bbox_left + 6;
        _x2 = bbox_right - 6;
        _y1 = bbox_top;
        _y2 = bbox_bottom + 16;
        _hb.facing = 0;
        _hb.edge_x = 0;
        _hb.edge_y1 = _y2;
        _hb.edge_y2 = _y2;
    } else {
        var _face = (last_direction != 0) ? last_direction : sign(image_xscale);
        if (_face == 0) _face = 1;
        _hb.facing = _face;

        if (_face > 0) {
            _x1 = bbox_right - ATTACK_HITBOX_X_INSET;
            _x2 = _x1 + _reach;
            _hb.edge_x = _x2;
        } else {
            _x2 = bbox_left + ATTACK_HITBOX_X_INSET;
            _x1 = _x2 - _reach;
            _hb.edge_x = _x1;
        }
        _hb.edge_y1 = _y1;
        _hb.edge_y2 = _y2;
    }

    _hb.x1 = _x1;
    _hb.y1 = _y1;
    _hb.x2 = _x2;
    _hb.y2 = _y2;
    return _hb;
}

/// @function scr_player_saber_trail_local_to_world
function scr_player_saber_trail_local_to_world(_ox, _oy, _face) {
    return {
        x: x + _face * _ox,
        y: y + _oy
    };
}

/// @function scr_player_saber_trail_arc_lerp
function scr_player_saber_trail_arc_lerp(_a0, _a1, _t) {
    return _a0 + angle_difference(_a1, _a0) * _t;
}

/// @function scr_player_saber_trail_get_blade_segment
/// @description Grip + tip world positions for the current active subimage.
/// @returns {Struct|undefined}
function scr_player_saber_trail_get_blade_segment() {
    if (!attacking) return undefined;

    var _idx = floor(image_index);
    if (_idx < 1 || _idx > 3) return undefined;

    var _finisher = (comboCount >= 2);
    var _grip_table = _finisher
        ? (variable_instance_exists(id, "SABER_TRAIL_ATK2_GRIP") ? SABER_TRAIL_ATK2_GRIP : undefined)
        : (variable_instance_exists(id, "SABER_TRAIL_ATK1_GRIP") ? SABER_TRAIL_ATK1_GRIP : undefined);
    var _tip_table = _finisher
        ? (variable_instance_exists(id, "SABER_TRAIL_ATK2_TIP") ? SABER_TRAIL_ATK2_TIP : undefined)
        : (variable_instance_exists(id, "SABER_TRAIL_ATK1_TIP") ? SABER_TRAIL_ATK1_TIP : undefined);

    if (_grip_table == undefined || _tip_table == undefined) return undefined;
    if (array_length(_grip_table) < _idx || array_length(_tip_table) < _idx) return undefined;

    var _grip = _grip_table[_idx - 1];
    var _tip = _tip_table[_idx - 1];
    if (array_length(_grip) < 2 || array_length(_tip) < 2) return undefined;

    var _face = (last_direction != 0) ? last_direction : sign(image_xscale);
    if (_face == 0) _face = 1;

    var _grip_w = scr_player_saber_trail_local_to_world(_grip[0], _grip[1], _face);
    var _tip_w = scr_player_saber_trail_local_to_world(_tip[0], _tip[1], _face);

    var _pivot_ox = (variable_instance_exists(id, "SABER_TRAIL_BODY_PIVOT_OX") ? SABER_TRAIL_BODY_PIVOT_OX : 6);
    var _pivot_oy = (variable_instance_exists(id, "SABER_TRAIL_BODY_PIVOT_OY") ? SABER_TRAIL_BODY_PIVOT_OY : -32);
    var _pivot_w = scr_player_saber_trail_local_to_world(_pivot_ox, _pivot_oy, _face);

    return {
        grip_x: _grip_w.x,
        grip_y: _grip_w.y,
        tip_x: _tip_w.x,
        tip_y: _tip_w.y,
        pivot_x: _pivot_w.x,
        pivot_y: _pivot_w.y,
        facing: _face,
        finisher: _finisher,
        frame_idx: _idx
    };
}

/// @function scr_player_saber_trail_pick_color
function scr_player_saber_trail_pick_color(_finisher) {
    if (_finisher) {
        var _cols2 = [
            make_colour_rgb(140, 220, 255),
            make_colour_rgb(100, 190, 255),
            make_colour_rgb(200, 245, 255)
        ];
        return _cols2[irandom(array_length(_cols2) - 1)];
    }

    var _cols1 = (variable_instance_exists(id, "SABER_TRAIL_COLORS_ATK1") && array_length(SABER_TRAIL_COLORS_ATK1) > 0)
        ? SABER_TRAIL_COLORS_ATK1
        : [
            make_colour_rgb(90, 175, 255),
            make_colour_rgb(70, 150, 255),
            make_colour_rgb(160, 215, 255)
        ];
    return _cols1[irandom(array_length(_cols1) - 1)];
}

/// @function scr_player_saber_trail_push
function scr_player_saber_trail_push(_px, _py, _vx, _vy, _life, _size, _col) {
    if (!(variable_instance_exists(id, "SABER_TRAIL_ENABLED") ? SABER_TRAIL_ENABLED : true)) return;
    if (!variable_instance_exists(id, "saber_trail_list")) saber_trail_list = [];

    var _max = (variable_instance_exists(id, "SABER_TRAIL_MAX") ? SABER_TRAIL_MAX : 120);
    while (array_length(saber_trail_list) >= _max) {
        array_delete(saber_trail_list, 0, 1);
    }

    array_push(saber_trail_list, {
        x: _px,
        y: _py,
        vx: _vx,
        vy: _vy,
        life: _life,
        max_life: _life,
        size: _size,
        col: _col
    });
}

/// @function scr_player_saber_trail_spawn_at
function scr_player_saber_trail_spawn_at(_px, _py, _tang, _finisher) {
    var _life_min = (variable_instance_exists(id, "SABER_TRAIL_LIFE_MIN") ? SABER_TRAIL_LIFE_MIN : 4);
    var _life_max = (variable_instance_exists(id, "SABER_TRAIL_LIFE_MAX") ? SABER_TRAIL_LIFE_MAX : 10);
    if (_finisher) _life_max += 2;

    var _spd = (variable_instance_exists(id, "SABER_TRAIL_SPEED") ? SABER_TRAIL_SPEED : 1.6);
    if (_finisher) _spd *= 1.1;

    var _vx = lengthdir_x(_spd * random_range(0.65, 1.0), _tang) + random_range(-0.12, 0.12);
    var _vy = lengthdir_y(_spd * random_range(0.65, 1.0), _tang) + random_range(-0.12, 0.12);
    var _sz = _finisher ? choose(1, 2, 2) : choose(1, 1, 2);

    scr_player_saber_trail_push(
        _px + random_range(-0.5, 0.5),
        _py + random_range(-0.5, 0.5),
        _vx, _vy,
        irandom_range(_life_min, _life_max),
        _sz,
        scr_player_saber_trail_pick_color(_finisher)
    );
}

/// @function scr_player_saber_trail_spawn_blade_line
/// @param {Real} _x0
/// @param {Real} _y0
/// @param {Real} _x1
/// @param {Real} _y1
/// @param {Bool} _finisher
function scr_player_saber_trail_spawn_blade_line(_x0, _y0, _x1, _y1, _finisher) {
    var _samples = (variable_instance_exists(id, "SABER_TRAIL_BLADE_SAMPLES") ? SABER_TRAIL_BLADE_SAMPLES : 4);
    if (_finisher) _samples += 1;

    var _tang = point_direction(_x0, _y0, _x1, _y1);
    for (var _i = 0; _i < _samples; _i++) {
        var _t = (_samples <= 1) ? 1 : (_i / (_samples - 1));
        scr_player_saber_trail_spawn_at(lerp(_x0, _x1, _t), lerp(_y0, _y1, _t), _tang, _finisher);
    }
}

/// @function scr_player_saber_trail_spawn_swing_bridge
/// @description Curved bridge between previous tip and current grip (waist pivot).
function scr_player_saber_trail_spawn_swing_bridge(_seg, _from_x, _from_y, _to_x, _to_y) {
    var _samples = (variable_instance_exists(id, "SABER_TRAIL_ARC_SAMPLES") ? SABER_TRAIL_ARC_SAMPLES : 5);
    if (_seg.finisher) {
        _samples = (variable_instance_exists(id, "SABER_TRAIL_ARC_SAMPLES_ATK2") ? SABER_TRAIL_ARC_SAMPLES_ATK2 : 7);
    }

    var _px = _seg.pivot_x;
    var _py = _seg.pivot_y;
    var _ang0 = point_direction(_px, _py, _from_x, _from_y);
    var _ang1 = point_direction(_px, _py, _to_x, _to_y);
    var _r0 = point_distance(_px, _py, _from_x, _from_y);
    var _r1 = point_distance(_px, _py, _to_x, _to_y);

    for (var _i = 1; _i < _samples; _i++) {
        var _t = _i / _samples;
        var _ang = scr_player_saber_trail_arc_lerp(_ang0, _ang1, _t);
        var _r = lerp(_r0, _r1, _t);
        var _ang_next = scr_player_saber_trail_arc_lerp(_ang0, _ang1, min(1, _t + 0.1));
        var _bx = _px + lengthdir_x(_r, _ang);
        var _by = _py + lengthdir_y(_r, _ang);
        var _nx = _px + lengthdir_x(_r, _ang_next);
        var _ny = _py + lengthdir_y(_r, _ang_next);
        var _tang = point_direction(_bx, _by, _nx, _ny);
        scr_player_saber_trail_spawn_at(_bx, _by, _tang, _seg.finisher);
    }
}

/// @function scr_player_saber_trail_spawn_edge
/// @description Spawn particles along the blade path for the current animation frame.
/// @param {Struct} _hb Output from scr_player_attack_compute_hitbox (used for downward strike only)
function scr_player_saber_trail_spawn_edge(_hb) {
    if (!(variable_instance_exists(id, "SABER_TRAIL_ENABLED") ? SABER_TRAIL_ENABLED : true)) return;
    if (global.hitstop > 0) return;
    if (!_hb.active) return;

    if (_hb.downward) {
        var _finisher = (comboCount >= 2);
        var _samples = 5;
        var _life_min = (variable_instance_exists(id, "SABER_TRAIL_LIFE_MIN") ? SABER_TRAIL_LIFE_MIN : 4);
        var _life_max = (variable_instance_exists(id, "SABER_TRAIL_LIFE_MAX") ? SABER_TRAIL_LIFE_MAX : 10);
        var _spd = (variable_instance_exists(id, "SABER_TRAIL_SPEED") ? SABER_TRAIL_SPEED : 1.6);
        for (var _i = 0; _i < _samples; _i++) {
            var _t = (_samples <= 1) ? 0.5 : (_i / (_samples - 1));
            var _px = lerp(_hb.x1, _hb.x2, _t) + random_range(-1.5, 1.5);
            var _py = _hb.edge_y1 + random_range(-1, 1);
            scr_player_saber_trail_push(_px, _py, random_range(-0.4, 0.4), random_range(0.3, 1.0) * _spd,
                irandom_range(_life_min, _life_max), choose(1, 1, 2), scr_player_saber_trail_pick_color(_finisher));
        }
        return;
    }

    var _seg = scr_player_saber_trail_get_blade_segment();
    if (_seg == undefined) return;

    if (variable_instance_exists(id, "saber_trail_has_prev_tip")
        && saber_trail_has_prev_tip
        && saber_trail_arc_combo == comboCount
        && saber_trail_arc_idx == _seg.frame_idx - 1) {
        scr_player_saber_trail_spawn_swing_bridge(_seg,
            saber_trail_prev_tip_x, saber_trail_prev_tip_y,
            _seg.grip_x, _seg.grip_y);
    }

    scr_player_saber_trail_spawn_blade_line(
        _seg.grip_x, _seg.grip_y,
        _seg.tip_x, _seg.tip_y,
        _seg.finisher
    );

    saber_trail_prev_tip_x = _seg.tip_x;
    saber_trail_prev_tip_y = _seg.tip_y;
    saber_trail_has_prev_tip = true;
    saber_trail_arc_idx = _seg.frame_idx;
    saber_trail_arc_combo = comboCount;
}

/// @function scr_player_saber_trail_step
function scr_player_saber_trail_step() {
    if (!variable_instance_exists(id, "saber_trail_list")) return;
    if (global.hitstop > 0) return;

    var _drag = (variable_instance_exists(id, "SABER_TRAIL_DRAG") ? SABER_TRAIL_DRAG : 0.82);

    for (var _i = array_length(saber_trail_list) - 1; _i >= 0; _i--) {
        var _p = saber_trail_list[_i];
        _p.life -= 1;
        _p.vx *= _drag;
        _p.vy *= _drag;
        _p.x += _p.vx;
        _p.y += _p.vy;

        if (_p.life <= 0) {
            array_delete(saber_trail_list, _i, 1);
        } else {
            saber_trail_list[_i] = _p;
        }
    }
}

/// @function scr_player_saber_trail_draw
function scr_player_saber_trail_draw() {
    if (!variable_instance_exists(id, "saber_trail_list")) return;
    if (!(variable_instance_exists(id, "SABER_TRAIL_ENABLED") ? SABER_TRAIL_ENABLED : true)) return;
    if (array_length(saber_trail_list) <= 0) return;

    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_add);
    draw_set_color(c_white);

    for (var _i = 0; _i < array_length(saber_trail_list); _i++) {
        var _p = saber_trail_list[_i];
        var _t = _p.life / max(1, _p.max_life);
        var _fade = min(1, _t * 6) * min(1, (1 - _t) * 4);
        if (_fade <= 0.01) continue;

        draw_set_color(_p.col);
        draw_set_alpha(_fade * 0.9);
        var _px = floor(_p.x);
        var _py = floor(_p.y);
        var _s = _p.size;
        draw_rectangle(_px, _py, _px + _s - 1, _py + _s - 1, false);
    }

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

/// @function scr_player_saber_trail_clear
function scr_player_saber_trail_clear() {
    saber_trail_list = [];
    saber_trail_arc_idx = -1;
    saber_trail_arc_combo = 0;
    saber_trail_has_prev_tip = false;
}
