/// @file scr_player_ground_debris.gml
/// @description Purple ground kick-up particles at feet — walk, run, reel-back, land.

/// @function scr_player_ground_debris_feet_xy
/// @returns {Struct} Leading foot position for burst spawn.
function scr_player_ground_debris_feet_xy() {
    var _dir = sign(hsp);
    if (_dir == 0) {
        _dir = (variable_instance_exists(id, "last_direction") && last_direction != 0)
            ? last_direction : sign(image_xscale);
    }
    if (_dir == 0) _dir = 1;

    var _lead = (_dir > 0) ? floor(bbox_right) - 3 : floor(bbox_left) + 3;
    return {
        x: _lead,
        y: floor(bbox_bottom) - 1
    };
}

/// @function scr_player_ground_debris_pick_color
function scr_player_ground_debris_pick_color() {
    if (variable_instance_exists(id, "GROUND_DEBRIS_COLORS") && array_length(GROUND_DEBRIS_COLORS) > 0) {
        return GROUND_DEBRIS_COLORS[irandom(array_length(GROUND_DEBRIS_COLORS) - 1)];
    }
    var _cols = [
        make_color_rgb(94, 74, 102),   // #5E4A66 ground mid
        make_color_rgb(74, 59, 82),    // #4A3B52 ground base
        make_color_rgb(46, 36, 51),    // #2E2433 ground shadow
        make_color_rgb(125, 101, 133)  // #7D6585 tile edge highlight
    ];
    return _cols[irandom(array_length(_cols) - 1)];
}

/// @function scr_player_ground_debris_create
function scr_player_ground_debris_create(_px, _py, _vx, _vy, _life, _size, _col) {
    return {
        x: _px,
        y: _py,
        vx: _vx,
        vy: _vy,
        life: _life,
        max_life: _life,
        size: _size,
        col: _col,
        spin: random_range(-8, 8),
        rot: random(360),
        kind: 0
    };
}

/// @function scr_player_ground_debris_push_one
function scr_player_ground_debris_push_one(_px, _py, _vx, _vy, _life, _size) {
    if (!(variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true)) return;
    if (!variable_instance_exists(id, "ground_debris_list")) ground_debris_list = [];

    var _max = (variable_instance_exists(id, "GROUND_DEBRIS_MAX") ? GROUND_DEBRIS_MAX : 64);
    while (array_length(ground_debris_list) >= _max) {
        array_delete(ground_debris_list, 0, 1);
    }

    array_push(ground_debris_list, scr_player_ground_debris_create(
        _px, _py, _vx, _vy, _life, _size, scr_player_ground_debris_pick_color()));
}

/// @function scr_player_ground_debris_wall_contact_xy
/// @returns {Struct|undefined} Hand + foot contact points on the clung wall face.
function scr_player_ground_debris_wall_contact_xy() {
    if (!variable_instance_exists(id, "wall_side") || wall_side == 0) return undefined;

    var _edge = (wall_side < 0) ? floor(bbox_left) - 1 : floor(bbox_right) + 1;
    var _mid = floor((bbox_top + bbox_bottom) * 0.5);
    return {
        hand: { x: _edge, y: _mid - 6 },
        foot: { x: _edge, y: floor(bbox_bottom) - 3 }
    };
}

/// @function scr_player_ground_debris_wall_point_burst
/// @param {Struct} _pt { x, y }
/// @param {Real} _away_dir Horizontal kick (-wall_side): away from the wall surface.
/// @param {Real} _count
/// @param {Real} _lift
/// @param {Real} _spread
function scr_player_ground_debris_wall_point_burst(_pt, _away_dir, _count, _lift, _spread) {
    for (var _i = 0; _i < _count; _i++) {
        var _px = _pt.x + random_range(-2, 2);
        var _py = _pt.y + random_range(-2, 2);
        var _vx = _away_dir * random_range(0.6, 1.4) * _spread + random_range(-0.6, 0.6);
        var _vy = random_range(-_lift, _lift * 0.35);
        var _life = irandom_range(12, 22);
        var _size = choose(2, 2, 3, 3);
        scr_player_ground_debris_push_one(_px, _py, _vx, _vy, _life, _size);
    }
}

/// @function scr_player_ground_debris_on_wall_cling
/// @param {Bool} [_scrape] Periodic slide scrape vs initial grab.
function scr_player_ground_debris_on_wall_cling(_scrape) {
    if (argument_count < 1) _scrape = false;
    if (global.hitstop > 0) return;

    var _pts = scr_player_ground_debris_wall_contact_xy();
    if (_pts == undefined) return;

    var _away = -wall_side;
    var _spread = _scrape ? 1.2 : 1.5;
    var _lift = _scrape ? 1.4 : 1.0;
    var _hand_n = _scrape ? irandom_range(2, 4) : irandom_range(4, 6);
    var _foot_n = _scrape ? irandom_range(3, 5) : irandom_range(5, 7);

    scr_player_ground_debris_wall_point_burst(_pts.hand, _away, _hand_n, _lift, _spread);
    scr_player_ground_debris_wall_point_burst(_pts.foot, _away, _foot_n, _lift, _spread * 1.1);
}

/// @function scr_player_ground_debris_on_wall_jump
function scr_player_ground_debris_on_wall_jump() {
    if (global.hitstop > 0) return;

    var _pts = scr_player_ground_debris_wall_contact_xy();
    if (_pts == undefined) return;

    var _away = -wall_side;
    scr_player_ground_debris_wall_point_burst(_pts.hand, _away, irandom_range(5, 8), 2.6, 2.4);
    scr_player_ground_debris_wall_point_burst(_pts.foot, _away, irandom_range(6, 10), 3.0, 2.8);
}

/// @function scr_player_ground_debris_burst
/// @param {String} _kind "walk" | "run" | "reel" | "land" | "attack"
/// @param {Real} [_intensity] 0..1
/// @param {Real} [_face_override] Optional facing override (e.g. attack slide while hsp pushback flipped).
function scr_player_ground_debris_burst(_kind, _intensity, _face_override) {
    if (!(variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true)) return;
    if (global.hitstop > 0) return;

    if (argument_count < 2 || !is_real(_intensity)) _intensity = 0.6;
    _intensity = clamp(_intensity, 0.15, 1);

    if (!variable_instance_exists(id, "ground_debris_list")) ground_debris_list = [];

    var _move_dir = 1;
    if (argument_count >= 3 && is_real(_face_override) && _face_override != 0) {
        _move_dir = _face_override;
    } else {
        var _d = sign(hsp);
        if (_d != 0) {
            _move_dir = _d;
        } else if (variable_instance_exists(id, "last_direction") && is_real(last_direction) && last_direction != 0) {
            _move_dir = last_direction;
        } else {
            _d = sign(image_xscale);
            if (_d != 0) _move_dir = _d;
        }
    }

    var _feet = scr_player_ground_debris_feet_xy();
    if (argument_count >= 3 && is_real(_face_override) && _face_override != 0) {
        var _lead = (_move_dir > 0) ? floor(bbox_right) - 3 : floor(bbox_left) + 3;
        _feet = { x: _lead, y: floor(bbox_bottom) - 1 };
    }

    var _count = 6;
    var _spread_h = 1.8;
    var _lift = 2.0;
    var _back = 1.0;

    switch (_kind) {
        case "run":
            _count = irandom_range(8, 12);
            _spread_h = 3.0;
            _lift = 2.8;
            _back = 1.4;
            break;
        case "reel":
            _count = irandom_range(7, 10);
            _spread_h = 3.4;
            _lift = 1.8;
            _back = 2.6;
            break;
        case "land":
            _count = irandom_range(12, 18);
            _spread_h = 4.0;
            _lift = 3.4;
            _back = 0.6;
            break;
        case "attack":
            _count = irandom_range(5, 8);
            _spread_h = 2.4;
            _lift = 2.2;
            _back = 1.8;
            break;
        default: // walk / jog
            _count = irandom_range(5, 8);
            break;
    }

    _count = max(1, round(_count * lerp(0.85, 1.25, _intensity)));

    for (var _i = 0; _i < _count; _i++) {
        var _px = _feet.x + random_range(-4, 4);
        var _py = _feet.y + random_range(-2, 1);
        var _vx = random_range(-_spread_h, _spread_h) - _move_dir * _back * random_range(0.5, 1.1);
        var _vy = -random_range(0.5, 1.2) * _lift * _intensity;
        if (_kind == "land") {
            _vx = random_range(-_spread_h, _spread_h);
            _vy = -random_range(0.8, 1.6) * _lift * _intensity;
        }
        var _life = irandom_range(14, 26);
        if (_kind == "land") _life = irandom_range(18, 32);
        var _size = choose(2, 2, 3, 3, 4);
        if (_kind == "run" || _kind == "land") _size = choose(2, 3, 3, 4, 4, 5);

        scr_player_ground_debris_push_one(_px, _py, _vx, _vy, _life, _size);
    }
}

/// @function scr_player_ground_debris_step
function scr_player_ground_debris_step() {
    if (!variable_instance_exists(id, "ground_debris_list")) return;
    if (global.hitstop > 0) return;

    var _grav = (variable_instance_exists(id, "GROUND_DEBRIS_GRAVITY") ? GROUND_DEBRIS_GRAVITY : 0.22);
    var _drag = (variable_instance_exists(id, "GROUND_DEBRIS_DRAG") ? GROUND_DEBRIS_DRAG : 0.88);

    for (var _i = array_length(ground_debris_list) - 1; _i >= 0; _i--) {
        var _p = ground_debris_list[_i];
        _p.life -= 1;
        _p.vy += _grav;
        _p.vx *= _drag;
        _p.x += _p.vx;
        _p.y += _p.vy;
        _p.rot += _p.spin;

        if (_p.life <= 0) {
            array_delete(ground_debris_list, _i, 1);
        } else {
            ground_debris_list[_i] = _p;
        }
    }
}

/// @function scr_player_ground_debris_draw
function scr_player_ground_debris_draw() {
    if (!variable_instance_exists(id, "ground_debris_list")) return;
    if (!(variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true)) return;

    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_normal);

    for (var _i = 0; _i < array_length(ground_debris_list); _i++) {
        var _p = ground_debris_list[_i];
        var _t = _p.life / max(1, _p.max_life);
        var _fade = min(1, _t * 4) * min(1, (1 - _t) * 3);
        if (_fade <= 0.01) continue;

        draw_set_color(_p.col);
        draw_set_alpha(_fade);
        var _px = floor(_p.x);
        var _py = floor(_p.y);
        var _s = _p.size;
        draw_rectangle(_px, _py, _px + _s - 1, _py + _s - 1, false);
        if (_s >= 3) {
            draw_set_color(make_color_rgb(125, 101, 133));
            draw_set_alpha(_fade * 0.7);
            draw_rectangle(_px + 1, _py + 1, _px + _s - 2, _py + _s - 2, false);
        }
    }

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

/// @function scr_player_ground_debris_on_attack_shift
/// @param {Real} [_steps] Shift pixels applied this frame (scales burst).
function scr_player_ground_debris_on_attack_shift(_steps) {
    if (argument_count < 1) _steps = 1;
    if (!(variable_instance_exists(id, "GROUND_DEBRIS_ENABLED") ? GROUND_DEBRIS_ENABLED : true)) return;
    if (!grounded) return;

    var _dir = (last_direction != 0) ? last_direction : sign(image_xscale);
    if (_dir == 0) _dir = 1;

    var _combo_boost = (variable_instance_exists(id, "comboCount") && comboCount >= 2) ? 0.12 : 0;
    var _intensity = clamp(0.48 + _combo_boost + max(0, _steps - 1) * 0.06, 0.4, 0.82);
    scr_player_ground_debris_burst("attack", _intensity, _dir);
}

/// @function scr_player_ground_debris_on_step_contact
/// @param {Real} [_intensity] 0..1
function scr_player_ground_debris_on_step_contact(_intensity) {
    if (argument_count < 1) _intensity = scr_player_footsteps_speed_norm();

    var _kind = "walk";
    if (sprite_index == spr_mc_sprint) _kind = "run";
    else if (sprite_index == spr_mc_reelback) {
        _kind = "reel";
        _intensity = max(_intensity, 0.55);
    }

    scr_player_ground_debris_burst(_kind, _intensity);
}

/// @function scr_player_ground_debris_on_land
/// @param {Real} _impact_vsp
function scr_player_ground_debris_on_land(_impact_vsp) {
    var _ref = (variable_instance_exists(id, "LAND_SOUND_VSP_REF") ? LAND_SOUND_VSP_REF : 8);
    var _intensity = clamp(_impact_vsp / max(0.01, _ref), 0.25, 1);
    scr_player_ground_debris_burst("land", _intensity);
}
