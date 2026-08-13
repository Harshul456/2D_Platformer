/// Reusable cutscene director (camera pans, fades). State lives on obj_camera_controller.

enum CUTSCENE_KIND {
    NONE,
    CAMERA_SCOUT // Pan to a point, hold, fade black, snap back to player, fade in
}

enum CUTSCENE_PHASE {
    NONE,
    PAN,
    HOLD,
    FADE_OUT,
    BLACK,
    FADE_IN
}

/// @function scr_cutscene_played_ensure
/// @description Session map of cutscene ids already shown (survives room restart; not wiped by global_init).
function scr_cutscene_played_ensure() {
    if (!variable_global_exists("cutscenes_played")) {
        global.cutscenes_played = {};
    }
}

/// @function scr_cutscene_was_played
/// @param {String} _id
/// @returns {Bool}
function scr_cutscene_was_played(_id) {
    if (_id == undefined || _id == "") return false;
    scr_cutscene_played_ensure();
    return (variable_struct_exists(global.cutscenes_played, _id)
        && global.cutscenes_played[$ _id] == true);
}

/// @function scr_cutscene_mark_played
/// @param {String} _id
function scr_cutscene_mark_played(_id) {
    if (_id == undefined || _id == "") return;
    scr_cutscene_played_ensure();
    global.cutscenes_played[$ _id] = true;
}

/// @function scr_cutscene_init_controller
/// @description Ensure cutscene fields exist on the camera controller (Create or first use).
function scr_cutscene_init_controller() {
    if (!instance_exists(obj_camera_controller)) return;
    with (obj_camera_controller) {
        if (!variable_instance_exists(id, "cutscene_kind")) {
            cutscene_kind = CUTSCENE_KIND.NONE;
            cutscene_phase = CUTSCENE_PHASE.NONE;
            cutscene_timer = 0;
            cutscene_fade_alpha = 0;
            cutscene_look_x = 0;
            cutscene_look_y = 0;
            cutscene_pan_from_x = 0;
            cutscene_pan_from_y = 0;
            cutscene_pan_to_x = 0;
            cutscene_pan_to_y = 0;
            cutscene_pan_frames = 70;
            cutscene_hold_frames = 40;
            cutscene_fade_out_frames = 28;
            cutscene_black_frames = 10;
            cutscene_fade_in_frames = 28;
            cutscene_trigger_id = noone;
            cutscene_id = "";
            cutscene_player_prev_state = PLAYER_STATE.ALIVE;
        } else if (!variable_instance_exists(id, "cutscene_id")) {
            cutscene_id = "";
        }
    }
}

/// @function scr_cutscene_active
/// @returns {Bool}
function scr_cutscene_active() {
    if (!instance_exists(obj_camera_controller)) return false;
    scr_cutscene_init_controller();
    return (obj_camera_controller.cutscene_phase != CUTSCENE_PHASE.NONE);
}

/// @function scr_cutscene_locks_player
/// @returns {Bool}
function scr_cutscene_locks_player() {
    return scr_cutscene_active();
}

/// @function scr_cutscene_fade_hiding_hud
/// @returns {Bool}
function scr_cutscene_fade_hiding_hud() {
    if (!scr_cutscene_active()) return false;
    var _ph = obj_camera_controller.cutscene_phase;
    return (_ph == CUTSCENE_PHASE.FADE_OUT || _ph == CUTSCENE_PHASE.BLACK);
}

/// @function scr_cutscene_ease
/// @param {Real} _t 0..1
/// @returns {Real}
function scr_cutscene_ease(_t) {
    _t = clamp(_t, 0, 1);
    return _t * _t * (3 - 2 * _t);
}

/// @function scr_cutscene_cam_pos_for_point
/// @description Top-left view pos that centers (_cx,_cy), clamped to current camera bounds.
function scr_cutscene_cam_pos_for_point(_cx, _cy) {
    var _out = { x: 0, y: 0 };
    if (!instance_exists(obj_camera_controller)) return _out;
    with (obj_camera_controller) {
        var _max_x = max(global.camera_min_x, global.camera_max_x - cam_w);
        var _max_y = max(global.camera_min_y, global.camera_max_y - cam_h);
        _out.x = clamp(floor(_cx - cam_w * 0.5), global.camera_min_x, _max_x);
        _out.y = clamp(floor(_cy - cam_h * 0.5), global.camera_min_y, _max_y);
    }
    return _out;
}

/// @function scr_cutscene_lock_player
function scr_cutscene_lock_player() {
    if (!instance_exists(obj_player)) return;
    if (instance_exists(obj_camera_controller)
        && obj_player.state != PLAYER_STATE.CUTSCENE) {
        obj_camera_controller.cutscene_player_prev_state = obj_player.state;
    }
    with (obj_player) {
        // Cancel mid-attack so the freeze doesn't leave swing state hanging.
        if (variable_instance_exists(id, "attacking") && attacking) {
            attacking = false;
            attack_is_air = false;
            attack_no_lunge = false;
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
        state = PLAYER_STATE.CUTSCENE;
        can_move = false;
        hsp = 0;
        vsp = 0;
        // Full standstill — no leftover jog/sprint when fade returns
        if (variable_instance_exists(id, "is_sprinting")) is_sprinting = false;
        if (variable_instance_exists(id, "sprint_committed")) sprint_committed = false;
        if (variable_instance_exists(id, "sprint_dash_standstill")) sprint_dash_standstill = false;
        if (variable_instance_exists(id, "sprint_reel_active")) sprint_reel_active = false;
        if (variable_instance_exists(id, "sprint_reel_pending")) sprint_reel_pending = false;
        if (variable_instance_exists(id, "sprint_reel_dir_wait")) sprint_reel_dir_wait = 0;
        if (variable_instance_exists(id, "sprint_reel_wall")) sprint_reel_wall = false;
        if (variable_instance_exists(id, "dash_input_buffer")) dash_input_buffer = 0;
        if (variable_instance_exists(id, "dash_lock_timer")) dash_lock_timer = 0;
        if (variable_instance_exists(id, "dash_iframe_timer")) dash_iframe_timer = 0;
        if (variable_instance_exists(id, "sprint_squash_x")) {
            sprint_squash_x = 1;
            sprint_squash_y = 1;
            sprint_squash_coil_frames = 0;
        }
        scr_cutscene_force_idle_pose();
    }
}

/// @function scr_cutscene_force_idle_pose
/// @description Snap to grounded idle so cutscene / fade-in never shows mid-stride.
function scr_cutscene_force_idle_pose() {
    if (!instance_exists(obj_player)) return;
    with (obj_player) {
        hsp = 0;
        vsp = 0;
        if (sprite_exists(spr_mc_idle)) {
            if (sprite_index != spr_mc_idle) {
                sprite_index = spr_mc_idle;
                image_index = 0;
            }
        }
        image_speed = 1;
    }
}

/// @function scr_cutscene_unlock_player
function scr_cutscene_unlock_player() {
    if (!instance_exists(obj_player)) return;
    with (obj_player) {
        if (state == PLAYER_STATE.CUTSCENE) {
            state = PLAYER_STATE.ALIVE;
        }
        can_move = true;
        hsp = 0;
        vsp = 0;
        scr_cutscene_force_idle_pose();
    }
}

/// @function scr_cutscene_player_ready_for_trigger
/// @description Grounded only — mid-air overlap waits; once landed we freeze + start.
/// @param {Id.Instance} _pl
/// @returns {Bool}
function scr_cutscene_player_ready_for_trigger(_pl) {
    if (_pl == noone || !instance_exists(_pl)) return false;
    if (!variable_instance_exists(_pl, "grounded") || !_pl.grounded) return false;
    // Still rising / jumping — wait for a real land (grounded can flicker on lip frames).
    if (_pl.vsp < -0.1) return false;
    return true;
}

/// @function scr_cutscene_try_fire_trigger
/// @description If this obj_cutscene_trigger overlaps a grounded player and hasn't played, freeze + start.
/// @returns {Bool}
function scr_cutscene_try_fire_trigger() {
    if (one_shot) {
        if (triggered) return false;
        if (scr_cutscene_was_played(cutscene_id)) {
            triggered = true;
            return false;
        }
    }
    if (scr_cutscene_active()) return false;
    if (!instance_exists(obj_player)) return false;

    var _pl = obj_player;
    var _overlap = rectangle_in_rectangle(
        _pl.bbox_left, _pl.bbox_top, _pl.bbox_right, _pl.bbox_bottom,
        trigger_min_x, trigger_min_y, trigger_max_x, trigger_max_y
    );
    if (_overlap == 0) return false;
    // Armed while airborne — fire on land, then lock_player forces idle.
    if (!scr_cutscene_player_ready_for_trigger(_pl)) return false;

    if (cutscene_kind == CUTSCENE_KIND.CAMERA_SCOUT) {
        if (scr_cutscene_start_camera_scout(look_x, look_y, id, pan_frames, hold_frames)) {
            if (one_shot) {
                triggered = true;
                scr_cutscene_mark_played(cutscene_id);
            }
            return true;
        }
    }
    return false;
}

/// @function scr_cutscene_poll_triggers
/// @description Scan placeable triggers (called from camera End Step — reliable even if trigger Step is empty).
function scr_cutscene_poll_triggers() {
    if (scr_cutscene_active()) return;
    if (!instance_exists(obj_cutscene_trigger)) return;
    with (obj_cutscene_trigger) {
        if (scr_cutscene_try_fire_trigger()) break;
    }
}

/// @function scr_cutscene_start_camera_scout
/// @description Pan camera to (_look_x,_look_y), hold, fade out/in back on player. Health unchanged.
/// @param {Real} _look_x
/// @param {Real} _look_y
/// @param {Id.Instance} [_trigger] Optional trigger to mark consumed
/// @param {Real} [_pan_frames]
/// @param {Real} [_hold_frames]
function scr_cutscene_start_camera_scout(_look_x, _look_y) {
    if (!instance_exists(obj_camera_controller) || !instance_exists(obj_player)) return false;
    if (scr_cutscene_active()) return false;
    // Don't interrupt death / combat death dissolve
    with (obj_player) {
        if (state == PLAYER_STATE.DEATH) return false;
        if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
            && death_fade_phase != DEATH_SEQ.NONE) return false;
        if (is_dying) return false;
    }

    var _trigger = noone;
    if (argument_count > 2) _trigger = argument[2];
    var _pan = 70;
    var _hold = 40;
    if (argument_count > 3 && argument[3] > 0) _pan = argument[3];
    if (argument_count > 4 && argument[4] > 0) _hold = argument[4];

    scr_cutscene_init_controller();
    scr_camera_clear_shake();

    with (obj_camera_controller) {
        cutscene_kind = CUTSCENE_KIND.CAMERA_SCOUT;
        cutscene_phase = CUTSCENE_PHASE.PAN;
        cutscene_timer = 0;
        cutscene_fade_alpha = 0;
        cutscene_look_x = _look_x;
        cutscene_look_y = _look_y;
        cutscene_pan_frames = _pan;
        cutscene_hold_frames = _hold;
        cutscene_fade_out_frames = 28;
        cutscene_black_frames = 10;
        cutscene_fade_in_frames = 28;
        cutscene_trigger_id = _trigger;
        cutscene_id = "";
        if (_trigger != noone && instance_exists(_trigger)
            && variable_instance_exists(_trigger, "cutscene_id")) {
            cutscene_id = _trigger.cutscene_id;
        }

        cutscene_pan_from_x = camera_get_view_x(cam);
        cutscene_pan_from_y = camera_get_view_y(cam);
        var _to = scr_cutscene_cam_pos_for_point(_look_x, _look_y);
        cutscene_pan_to_x = _to.x;
        cutscene_pan_to_y = _to.y;

        scr_cutscene_lock_player();
    }
    return true;
}

/// @function scr_cutscene_finish
function scr_cutscene_finish() {
    if (!instance_exists(obj_camera_controller)) return;
    with (obj_camera_controller) {
        if (cutscene_trigger_id != noone && instance_exists(cutscene_trigger_id)) {
            cutscene_trigger_id.triggered = true;
        }
        // Persist for this room/session so reloads don't replay
        if (variable_instance_exists(id, "cutscene_id")) {
            scr_cutscene_mark_played(cutscene_id);
        }
        cutscene_kind = CUTSCENE_KIND.NONE;
        cutscene_phase = CUTSCENE_PHASE.NONE;
        cutscene_timer = 0;
        cutscene_fade_alpha = 0;
        cutscene_trigger_id = noone;
        cutscene_id = "";
        // Resync follow trail so look-ahead doesn't jump
        if (instance_exists(obj_player)) {
            camera_prev_player_x = obj_player.x;
            camera_prev_player_y = obj_player.y;
            cam_look_ahead = 0;
        }
    }
    scr_cutscene_unlock_player();
}

/// @function scr_cutscene_step
/// @description Drive active cutscene; owns the camera while running (call instead of scr_camera_control).
function scr_cutscene_step() {
    if (!instance_exists(obj_camera_controller)) return;
    scr_cutscene_init_controller();
    if (!scr_cutscene_active()) return;

    with (obj_camera_controller) {
        // Keep player planted + idle every frame
        if (instance_exists(obj_player)) {
            obj_player.hsp = 0;
            obj_player.vsp = 0;
            obj_player.can_move = false;
            scr_cutscene_force_idle_pose();
        }

        cutscene_timer++;

        switch (cutscene_phase) {
            case CUTSCENE_PHASE.PAN: {
                var _dur = max(1, cutscene_pan_frames);
                var _u = scr_cutscene_ease(cutscene_timer / _dur);
                var _x = lerp(cutscene_pan_from_x, cutscene_pan_to_x, _u);
                var _y = lerp(cutscene_pan_from_y, cutscene_pan_to_y, _u);
                camera_set_view_pos(cam, floor(_x), floor(_y));
                scr_parallax_update();
                if (cutscene_timer >= _dur) {
                    camera_set_view_pos(cam, cutscene_pan_to_x, cutscene_pan_to_y);
                    cutscene_phase = CUTSCENE_PHASE.HOLD;
                    cutscene_timer = 0;
                }
            } break;

            case CUTSCENE_PHASE.HOLD: {
                camera_set_view_pos(cam, cutscene_pan_to_x, cutscene_pan_to_y);
                scr_parallax_update();
                if (cutscene_timer >= max(1, cutscene_hold_frames)) {
                    cutscene_phase = CUTSCENE_PHASE.FADE_OUT;
                    cutscene_timer = 0;
                }
            } break;

            case CUTSCENE_PHASE.FADE_OUT: {
                var _fout = max(1, cutscene_fade_out_frames);
                cutscene_fade_alpha = scr_cutscene_ease(cutscene_timer / _fout);
                scr_parallax_update();
                if (cutscene_timer >= _fout) {
                    cutscene_fade_alpha = 1;
                    cutscene_phase = CUTSCENE_PHASE.BLACK;
                    cutscene_timer = 0;
                    // Snap under black immediately — player stays put, HP untouched
                    scr_camera_snap_to_player();
                }
            } break;

            case CUTSCENE_PHASE.BLACK: {
                cutscene_fade_alpha = 1;
                scr_parallax_update();
                if (cutscene_timer >= max(1, cutscene_black_frames)) {
                    cutscene_phase = CUTSCENE_PHASE.FADE_IN;
                    cutscene_timer = 0;
                }
            } break;

            case CUTSCENE_PHASE.FADE_IN: {
                var _fin = max(1, cutscene_fade_in_frames);
                cutscene_fade_alpha = 1 - scr_cutscene_ease(cutscene_timer / _fin);
                // Keep cam on player while revealing
                if (instance_exists(obj_player)) {
                    // Soft follow isn't needed — snap already placed us; hold until unlock
                    scr_parallax_update();
                }
                if (cutscene_timer >= _fin) {
                    cutscene_fade_alpha = 0;
                    scr_cutscene_finish();
                }
            } break;
        }
    }
}

/// @function scr_cutscene_debug_draw
/// @description Draw trigger boxes + look targets when global.show_debug is on.
function scr_cutscene_debug_draw() {
    if (!variable_global_exists("show_debug") || !global.show_debug) return;

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_halign = draw_get_halign();
    var _old_valign = draw_get_valign();

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);

    var _n = instance_number(obj_cutscene_trigger);
    if (_n <= 0) {
        // Visible proof the asset/instance is missing from the running room
        if (instance_exists(obj_player)) {
            draw_set_color(c_red);
            draw_text(obj_player.x - 40, obj_player.y - 48, "NO cutscene triggers");
        }
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        draw_set_halign(_old_halign);
        draw_set_valign(_old_valign);
        return;
    }

    with (obj_cutscene_trigger) {
        var _done = triggered || scr_cutscene_was_played(cutscene_id);
        var _col = _done ? make_color_rgb(140, 140, 140) : make_color_rgb(255, 40, 255);

        // Bright fill + thick outline (readable on dark cave)
        draw_set_alpha(0.25);
        draw_set_color(_col);
        draw_rectangle(trigger_min_x, trigger_min_y, trigger_max_x, trigger_max_y, false);
        draw_set_alpha(1);
        draw_rectangle(trigger_min_x, trigger_min_y, trigger_max_x, trigger_max_y, true);
        draw_rectangle(trigger_min_x + 1, trigger_min_y + 1, trigger_max_x - 1, trigger_max_y - 1, true);

        draw_circle(x, y, 4, false);

        // Box center (asymmetric height means this ≠ instance x,y)
        var _cx = (trigger_min_x + trigger_max_x) * 0.5;
        var _cy = (trigger_min_y + trigger_max_y) * 0.5;
        draw_circle(_cx, _cy, 3, true);

        if (variable_instance_exists(id, "look_x")) {
            draw_set_color(make_color_rgb(0, 255, 255));
            draw_circle(look_x, look_y, 8, true);
            draw_line(look_x - 12, look_y, look_x + 12, look_y);
            draw_line(look_x, look_y - 12, look_x, look_y + 12);
            draw_set_alpha(0.5);
            draw_line(_cx, _cy, look_x, look_y);
            draw_set_alpha(1);
        }

        draw_set_color(_col);
        var _label = (cutscene_id != "") ? cutscene_id : "cutscene";
        if (_done) _label += " [done]";
        draw_text(trigger_min_x + 4, trigger_min_y + 4, _label);
        draw_text(trigger_min_x + 4, trigger_min_y + 16,
            string(floor(trigger_min_x)) + "," + string(floor(trigger_min_y))
            + " -> " + string(floor(trigger_max_x)) + "," + string(floor(trigger_max_y)));
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    draw_set_halign(_old_halign);
    draw_set_valign(_old_valign);
}

/// @function scr_cutscene_draw_fade
/// @description Same void-style overlay as death fade (call after death fade draw).
function scr_cutscene_draw_fade() {
    if (!instance_exists(obj_camera_controller)) return;
    scr_cutscene_init_controller();
    with (obj_camera_controller) {
        if (cutscene_fade_alpha <= 0.001) exit;

        var _vx = camera_get_view_x(cam);
        var _vy = camera_get_view_y(cam);
        var _vw = camera_get_view_width(cam);
        var _vh = camera_get_view_height(cam);

        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();
        var _old_blend = gpu_get_blendmode();

        gpu_set_blendmode(bm_normal);
        draw_set_alpha(clamp(cutscene_fade_alpha, 0, 1));
        draw_set_color(make_color_rgb(6, 3, 12));
        draw_rectangle(_vx - 2, _vy - 2, _vx + _vw + 2, _vy + _vh + 2, false);

        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}
