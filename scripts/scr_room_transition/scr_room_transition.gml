/// Room edges. One row is one connection. The right side of `left` enters the
/// left side of `right`, and that left side comes back. Feet y is the path in
/// each room. How far inside the doorway you appear comes from the player mask,
/// so a new room only adds a row. A room in the middle is the `right` of one
/// row and the `left` of the next; the exit follows the edge you are standing on.

enum ROOM_TRANS {
    NONE,
    FADE_OUT,
    FADE_IN
}

#macro ROOM_TRANSITION_FADE_FRAMES 12

/// @function scr_room_links
function scr_room_links() {
    return [
        { left: room_test, left_y: 960, right: room_test2, right_y: 352 },
        { left: room_test2, left_y: 288, right: room_test3, right_y: 1696 },
    ];
}

/// @function scr_room_music_groups
/// @description Rooms in one group keep the same looping track. A room in no group is silent.
function scr_room_music_groups() {
    return [
        { sound: s_past, rooms: [room_test, room_test2, room_test3] },
    ];
}

/// @function scr_room_transition_globals_ensure
/// @description Survives global_init. Never resets a trip that is already in progress.
function scr_room_transition_globals_ensure() {
    if (!variable_global_exists("room_transition_phase")) {
        global.room_transition_phase = ROOM_TRANS.NONE;
        global.room_transition_timer = 0;
        global.room_transition_alpha = 0;
        global.room_arrive_edge = 0;
        global.room_arrive_x = 0;
        global.room_arrive_y = 0;
        global.room_arrive_face = 1;
        global.room_transition_target = noone;
        global.room_carry_health = -1;
    }
    if (!variable_global_exists("music_id")) {
        global.music_id = -1;
        global.music_sound = -1;
    }
}

/// @function scr_room_link_for_edge
/// @description The row that owns this edge. +1 is the right edge (this room is `left`), -1 is the left edge.
function scr_room_link_for_edge(_dir) {
    if (_dir == 0) return undefined;
    var _links = scr_room_links();
    var _n = array_length(_links);
    for (var _i = 0; _i < _n; _i++) {
        var _link = _links[_i];
        if (_dir > 0 && _link.left == room) return _link;
        if (_dir < 0 && _link.right == room) return _link;
    }
    return undefined;
}

/// @function scr_room_exit_dir
/// @description +1 on a linked right edge, -1 on a linked left edge, 0 in the middle of the room.
function scr_room_exit_dir() {
    if (x >= room_width - 48 && !is_undefined(scr_room_link_for_edge(1))) return 1;
    if (x <= 48 && !is_undefined(scr_room_link_for_edge(-1))) return -1;
    return 0;
}

/// @function scr_room_link_dest
/// @description The other end of the edge the player is on. `side` is the doorway you appear in (-1 left, +1 right).
function scr_room_link_dest() {
    var _dir = scr_room_exit_dir();
    var _link = scr_room_link_for_edge(_dir);
    if (is_undefined(_link)) return undefined;
    if (_dir > 0) {
        return { dest: _link.right, y: _link.right_y, side: -1, face: 1 };
    }
    return { dest: _link.left, y: _link.left_y, side: 1, face: -1 };
}

/// @function scr_room_entry_feet_x
/// @description Feet x just inside a doorway. Left entries sit about a body-half in from x = 0.
function scr_room_entry_feet_x(_side) {
    var _pad = 3;
    var _to_left = x - bbox_left;
    var _to_right = bbox_right - x;
    if (_to_left < 1) _to_left = 14;
    if (_to_right < 1) _to_right = 13;
    if (_side < 0) return _to_left + _pad;
    return room_width - _to_right - _pad;
}

/// @function scr_room_exit_is_crossing
/// @description Body is on a linked room edge. Landing crouch and the side-embed shove zero hsp,
///             so this cannot depend on speed: the next frame would miss the lock and play fall.
function scr_room_exit_is_crossing() {
    var _dir = scr_room_exit_dir();
    if (_dir == 0) return false;
    if (variable_instance_exists(id, "jumped_this_frame") && jumped_this_frame) return false;
    if (variable_instance_exists(id, "jump_count") && jump_count > 0) return false;
    if (vsp < -1) return false;
    // 64px sprite, origin at 32. Lock once the drawn body meets the edge, before the
    // center foot leaves the tile and the fall / land poses start swapping.
    if (_dir > 0) return x >= room_width - 48;
    return x <= 48;
}

/// @function scr_room_exit_lock_ground
/// @description Outside the room the floor probes are empty, so land and fall swap every frame.
function scr_room_exit_lock_ground() {
    if (!scr_room_exit_is_crossing()) return false;
    grounded = true;
    vsp = 0;
    return true;
}

/// @function scr_room_exit_lock_pose
/// @description The ground branch keeps the jump sprite and replays the landing crouch after a one-frame fall.
function scr_room_exit_lock_pose() {
    if (!scr_room_exit_lock_ground()) return;
    if (variable_instance_exists(id, "force_landing_crouch") && force_landing_crouch) return;
    if (attacking) return;
    if (sprite_index != spr_mc_jump && sprite_index != spr_mc_doublejump && sprite_index != spr_mc_walljump) return;
    var _move = abs(hsp) > 0.5;
    if (variable_instance_exists(id, "key_right") && variable_instance_exists(id, "key_left")) {
        _move = _move || ((key_right - key_left) != 0);
    }
    sprite_index = (is_sprinting || sprint_committed) ? spr_mc_sprint : (_move ? spr_mc_jog : spr_mc_idle);
    image_index = 0;
    image_speed = 1;
}

/// @function scr_room_transition_hold_exit_line
/// @description Once the body crosses a linked edge, keep the feet on the path so the walk off screen doesn't drop.
function scr_room_transition_hold_exit_line(_grounded_in, _y_in) {
    if (!scr_room_exit_is_crossing()) return;
    if (_grounded_in) exit_line_y = _y_in;
    if (variable_instance_exists(id, "exit_line_y")) y = exit_line_y;
    vsp = 0;
    grounded = true;
}

/// @function scr_room_transition_blocks_player
function scr_room_transition_blocks_player() {
    scr_room_transition_globals_ensure();
    return global.room_transition_phase != ROOM_TRANS.NONE;
}

/// @function scr_room_transition_try
/// @description After movement. The body has to leave the room before the fade starts.
function scr_room_transition_try() {
    scr_room_transition_globals_ensure();
    if (global.room_transition_phase != ROOM_TRANS.NONE) return;
    if (is_dying || (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve)) return;
    if (state == PLAYER_STATE.DEATH || state == PLAYER_STATE.CUTSCENE) return;

    var _dir = scr_room_exit_dir();
    if (_dir == 0) return;
    var _off = (_dir > 0 && bbox_left >= room_width) || (_dir < 0 && bbox_right <= 0);
    if (!_off) return;

    var _trip = scr_room_link_dest();
    if (is_undefined(_trip)) return;

    global.room_transition_phase = ROOM_TRANS.FADE_OUT;
    global.room_transition_timer = ROOM_TRANSITION_FADE_FRAMES;
    global.room_transition_alpha = 0;
    global.room_transition_target = _trip.dest;
    global.room_arrive_edge = _trip.side;
    global.room_arrive_y = _trip.y;
    global.room_arrive_face = _trip.face;
    global.room_carry_health = obj_player_health;
    hsp = 0;
    vsp = 0;
}

/// @function scr_room_transition_step
/// @description Advance the fade. The room changes on the black frame.
function scr_room_transition_step() {
    scr_room_transition_globals_ensure();
    if (global.room_transition_phase == ROOM_TRANS.NONE) return;

    var _n = ROOM_TRANSITION_FADE_FRAMES;
    hsp = 0;
    vsp = 0;

    if (global.room_transition_phase == ROOM_TRANS.FADE_OUT) {
        global.room_transition_timer--;
        var _u = 1 - (global.room_transition_timer / max(1, _n));
        global.room_transition_alpha = scr_player_death_ease(_u);
        if (global.room_transition_timer <= 0) {
            global.room_transition_alpha = 1;
            global.room_transition_phase = ROOM_TRANS.FADE_IN;
            global.room_transition_timer = _n;
            global.tilemap_collision_id = noone;
            var _to = global.room_transition_target;
            if (_to != noone && _to != room) room_goto(_to);
        }
    } else if (global.room_transition_phase == ROOM_TRANS.FADE_IN) {
        global.room_transition_timer--;
        var _u_in = global.room_transition_timer / max(1, _n);
        global.room_transition_alpha = scr_player_death_ease(max(0, _u_in));
        if (global.room_transition_timer <= 0) {
            global.room_transition_phase = ROOM_TRANS.NONE;
            global.room_transition_alpha = 0;
            global.room_arrive_edge = 0;
            global.room_transition_target = noone;
            can_move = true;
        }
    }
}

/// @function scr_room_transition_apply_arrival
/// @description Room Start. Place the new player on the feet this link names.
/// @returns {Bool} True when this entry was a door trip, so the editor spawn stays the death fallback.
function scr_room_transition_apply_arrival() {
    scr_room_transition_globals_ensure();
    if (global.room_arrive_edge == 0) return false;
    if (global.room_transition_phase != ROOM_TRANS.FADE_IN) return false;

    x = scr_room_entry_feet_x(global.room_arrive_edge);
    y = global.room_arrive_y;
    var _face = global.room_arrive_face;
    if (_face == 0) _face = 1;
    last_direction = _face;
    image_xscale = _face * abs(image_base_scale);
    hsp = 0;
    vsp = 0;
    grounded = true;
    sprite_index = spr_mc_idle;
    image_index = 0;
    image_speed = 1;

    if (global.room_carry_health >= 0) {
        obj_player_health = global.room_carry_health;
        scr_player_hud_sync_health();
        global.room_carry_health = -1;
    }

    if (instance_exists(obj_camera_zone)) {
        var _z = scr_camera_zone_find_at(x, y);
        if (_z != noone) with (_z) scr_camera_zone_activate();
    }
    if ((global.camera_max_x - global.camera_min_x) < 640
        || global.camera_min_x < 0 || global.camera_max_x > room_width) {
        global.camera_min_x = 0;
        global.camera_max_x = room_width;
        global.camera_min_y = 0;
        global.camera_max_y = room_height;
    }
    scr_camera_snap_to_player();
    return true;
}

/// @function scr_room_transition_fade_draw
/// @description Full-view veil. Same pass as the death fade, so it shows with or without lighting.
function scr_room_transition_fade_draw() {
    scr_room_transition_globals_ensure();
    if (global.room_transition_alpha <= 0.001) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;

    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = camera_get_view_width(_cam);
    var _vh = camera_get_view_height(_cam);

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_blend = gpu_get_blendmode();

    gpu_set_blendmode(bm_normal);
    draw_set_alpha(clamp(global.room_transition_alpha, 0, 1));
    draw_set_color(make_color_rgb(6, 3, 12));
    draw_rectangle(_vx - 2, _vy - 2, _vx + _vw + 2, _vy + _vh + 2, false);

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

/// @function scr_room_music_for
/// @description The looping track for this room, or -1 when the room stays silent.
function scr_room_music_for(_room) {
    var _groups = scr_room_music_groups();
    var _n = array_length(_groups);
    for (var _i = 0; _i < _n; _i++) {
        var _rooms = _groups[_i].rooms;
        var _rn = array_length(_rooms);
        for (var _r = 0; _r < _rn; _r++) {
            if (_rooms[_r] == _room) return _groups[_i].sound;
        }
    }
    return -1;
}

/// @function scr_room_music_sync
/// @description Keep the current track if this room shares it. Otherwise stop it and start the room's track.
function scr_room_music_sync() {
    scr_room_transition_globals_ensure();
    var _want = scr_room_music_for(room);
    var _playing = (global.music_id != -1 && audio_is_playing(global.music_id));
    if (_want == global.music_sound && (_want == -1 || _playing)) return;
    if (_playing) audio_stop_sound(global.music_id);
    global.music_id = -1;
    global.music_sound = -1;
    if (_want == -1) return;
    global.music_id = audio_play_sound(_want, 1, true);
    global.music_sound = _want;
}
