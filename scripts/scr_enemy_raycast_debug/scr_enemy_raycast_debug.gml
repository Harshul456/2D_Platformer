/// @file scr_enemy_raycast_debug.gml
/// @description Visual debug for enemy LOS / patrol / attack ray probes (toggle with F3).

/// @function scr_enemy_raycast_debug_probe
/// @description Sample a segment the same way scr_enemy_raycast does; return first hit.
/// @returns {Struct} { blocked: Bool, hit_x: Real, hit_y: Real }
function scr_enemy_raycast_debug_probe(_x1, _y1, _x2, _y2, _tiles_only) {
    if (variable_instance_exists(id, "vsp") && variable_instance_exists(id, "shelf_bb_bottom_prev")) {
        tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);
    }

    var _dist = point_distance(_x1, _y1, _x2, _y2);
    if (_dist < 0.5) {
        var _blocked = _tiles_only ? check_tile_collision(_x1, _y1) : scr_enemy_raycast(_x1, _y1, _x2, _y2);
        return { blocked: _blocked, hit_x: _x1, hit_y: _y1 };
    }

    var _step = ENEMY_RAYCAST_TILE_STEP;
    var _steps = max(1, ceil(_dist / _step));

    if (!_tiles_only) {
        for (var _i = 1; _i <= _steps; _i++) {
            var _t = _i / _steps;
            var _sx = lerp(_x1, _x2, _t);
            var _sy = lerp(_y1, _y2, _t);
            if (collision_point(_sx, _sy, obj_solid, true, true) != noone) {
                return { blocked: true, hit_x: _sx, hit_y: _sy };
            }
        }
    }

    for (var _j = 1; _j <= _steps; _j++) {
        var _tj = _j / _steps;
        var _tx = lerp(_x1, _x2, _tj);
        var _ty = lerp(_y1, _y2, _tj);
        if (check_tile_collision(_tx, _ty)) {
            return { blocked: true, hit_x: _tx, hit_y: _ty };
        }
    }

    return { blocked: false, hit_x: _x2, hit_y: _y2 };
}

/// @function scr_enemy_raycast_debug_draw_ray
/// @returns {Bool} True if segment is blocked.
function scr_enemy_raycast_debug_draw_ray(_x1, _y1, _x2, _y2, _tiles_only, _clear_col, _block_col) {
    var _probe = scr_enemy_raycast_debug_probe(_x1, _y1, _x2, _y2, _tiles_only);
    var _col = _probe.blocked ? _block_col : _clear_col;

    draw_set_color(_col);
    draw_line(floor(_x1), floor(_y1), floor(_x2), floor(_y2));
    draw_circle(floor(_x1), floor(_y1), 2, false);

    if (_probe.blocked) {
        draw_set_color(_block_col);
        draw_circle(floor(_probe.hit_x), floor(_probe.hit_y), 4, true);
    } else {
        draw_circle(floor(_x2), floor(_y2), 2, false);
    }

    return _probe.blocked;
}

/// @function scr_enemy_raycast_debug_draw_marker
function scr_enemy_raycast_debug_draw_marker(_px, _py, _radius, _col) {
    draw_set_color(_col);
    draw_circle(floor(_px), floor(_py), _radius, true);
    draw_circle(floor(_px), floor(_py), 1, false);
}

/// @function scr_enemy_raycast_debug_draw_floor_probes
function scr_enemy_raycast_debug_draw_floor_probes(_dir) {
    if (_dir == 0) return;

    tilecol_sync_actor_context(vsp, shelf_bb_bottom_prev);
    var _feet = bbox_bottom;
    var _lead = scr_enemy_horizontal_lead_x(sign(_dir));
    var _dx = _dir * 14;

    var _pts = [
        { x: _lead, y: _feet + 1 },
        { x: _lead, y: _feet + 4 },
        { x: _lead + _dx * 0.5, y: _feet + 6 },
        { x: _lead + _dx, y: _feet + 10 }
    ];

    for (var _i = 0; _i < array_length(_pts); _i++) {
        var _p = _pts[_i];
        var _hit = check_tile_collision(_p.x, _p.y);
        draw_set_color(_hit ? c_red : c_aqua);
        draw_rectangle(floor(_p.x) - 1, floor(_p.y) - 1, floor(_p.x) + 1, floor(_p.y) + 1, false);
    }
}

/// @function scr_enemy_raycast_debug_draw
function scr_enemy_raycast_debug_draw() {
    if (!(variable_global_exists("debug_enemy_raycast") && global.debug_enemy_raycast)) return;

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_halign = draw_get_halign();
    var _old_valign = draw_get_valign();

    draw_set_alpha(1);

    // --- LOS rays (same geometry as scr_enemy_dual_los_clear) ---
    var _channel_blocked = false;
    var _chest_blocked = false;
    var _los_clear = false;
    var _dist_total = 0;
    var _in_range = false;
    var _would_aggro = false;

    if (instance_exists(obj_player)) {
        var _ex = (bbox_left + bbox_right) * 0.5;
        var _ey = bbox_top + (bbox_bottom - bbox_top) * 0.35;
        var _px = (obj_player.bbox_left + obj_player.bbox_right) * 0.5;
        var _py = obj_player.bbox_top + (obj_player.bbox_bottom - obj_player.bbox_top) * 0.35;
        var _mid_y = (_ey + _py) * 0.5;

        scr_enemy_raycast_debug_draw_marker(_ex, _ey, 4, make_color_rgb(120, 255, 120));
        scr_enemy_raycast_debug_draw_marker(_px, _py, 4, make_color_rgb(255, 180, 80));
        scr_enemy_raycast_debug_draw_marker(_ex, _mid_y, 2, c_aqua);
        scr_enemy_raycast_debug_draw_marker(_px, _mid_y, 2, c_aqua);

        _channel_blocked = scr_enemy_raycast_debug_draw_ray(
            _ex, _mid_y, _px, _mid_y, true, c_lime, c_red);
        _chest_blocked = scr_enemy_raycast_debug_draw_ray(
            _ex, _ey, _px, _py, false, make_color_rgb(255, 255, 80), c_red);

        _los_clear = scr_enemy_dual_los_clear();
        _dist_total = point_distance(x, y, obj_player.x, obj_player.y);
        _in_range = (_dist_total < chaseRange);
        var _reaggro_cd = (variable_instance_exists(id, "chase_reaggro_cooldown") ? chase_reaggro_cooldown : 0);
        _would_aggro = (_in_range && _los_clear && _reaggro_cd <= 0 && state == ENEMY_STATE.PATROL);
    }

    // --- Chase range ring ---
    var _range = (variable_instance_exists(id, "chaseRange") ? chaseRange : 500);
    draw_set_color(make_color_rgb(180, 180, 220));
    draw_circle(floor(x), floor(y), _range, true);

    // --- Forward wall probe (patrol / chase direction) ---
    var _toward = instance_exists(obj_player) ? scr_enemy_dir_toward_player() : sign(hsp);
    if (_toward == 0) _toward = (variable_instance_exists(id, "patrol_dir") ? patrol_dir : sign(image_xscale));
    if (_toward != 0) {
        var _h_step = sign(_toward);
        var _center_y = floor((bbox_top + bbox_bottom) * 0.5);
        var _wx1 = (_h_step > 0) ? bbox_right : bbox_left;
        var _wx2 = _wx1 + _h_step * 14;
        var _wall_hit = scr_enemy_raycast_debug_draw_ray(
            _wx1, _center_y, _wx2, _center_y, false, make_color_rgb(220, 120, 255), c_fuchsia);

        scr_enemy_raycast_debug_draw_floor_probes(_toward);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(c_fuchsia);
        draw_text(floor(_wx2) + 4, floor(_center_y) - 8,
            "wall:" + (_wall_hit ? "HIT" : "clr"));
    }

    // --- HUD above enemy ---
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);

    var _y = bbox_top - 8;
    var _los_txt = "LOS: ";
    if (!instance_exists(obj_player)) {
        _los_txt += "NO PLAYER";
        draw_set_color(c_gray);
    } else if (_los_clear) {
        _los_txt += "CLEAR";
        draw_set_color(c_lime);
    } else if (_channel_blocked) {
        _los_txt += "CHANNEL BLOCKED";
        draw_set_color(c_red);
    } else if (_chest_blocked) {
        _los_txt += "CHEST BLOCKED";
        draw_set_color(c_orange);
    } else {
        _los_txt += "BLOCKED";
        draw_set_color(c_red);
    }
    draw_text(floor(x), _y, _los_txt);
    _y -= 12;

    draw_set_color(c_white);
    draw_text(floor(x), _y,
        "st:" + string(state)
        + " dist:" + string(floor(_dist_total)) + "/" + string(floor(_range))
        + (_in_range ? " IN" : " out"));
    _y -= 12;

    var _lost = (variable_instance_exists(id, "lost_los_timer") ? lost_los_timer : 0);
    draw_set_color((_lost > 0) ? c_yellow : c_ltgray);
    draw_text(floor(x), _y,
        "lost_los:" + string(_lost) + "/" + string(ENEMY_LOST_LOS_DROP_FRAMES)
        + " reaggro_cd:" + string(variable_instance_exists(id, "chase_reaggro_cooldown") ? chase_reaggro_cooldown : 0));
    _y -= 12;

    draw_set_color(_would_aggro ? c_lime : c_gray);
    draw_text(floor(x), _y, _would_aggro ? "WOULD NOTICE" : "no spot");

    // --- Screen legend (first enemy only) ---
    if (id == instance_find(obj_enemy, 0)) {
        var _cam = view_camera[0];
        var _vx = camera_get_view_x(_cam);
        var _vy = camera_get_view_y(_cam);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(c_yellow);
        draw_text(_vx + 8, _vy + 8, "ENEMY RAYCAST DEBUG (F3)");
        draw_set_color(c_white);
        draw_text(_vx + 8, _vy + 24, "Green/yellow = clear LOS   Red = blocked + hit ring");
        draw_text(_vx + 8, _vy + 40, "Cyan dots = channel height   Lime/orange = chest origins");
        draw_text(_vx + 8, _vy + 56, "Magenta = wall probe   Aqua/red squares = floor probes");
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    draw_set_halign(_old_halign);
    draw_set_valign(_old_valign);
}

/// @function scr_enemy_raycast_debug_toggle
function scr_enemy_raycast_debug_toggle() {
    if (!variable_global_exists("debug_enemy_raycast")) global.debug_enemy_raycast = false;
    global.debug_enemy_raycast = !global.debug_enemy_raycast;
}
