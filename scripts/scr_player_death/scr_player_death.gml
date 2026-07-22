/// Player combat-death: hurt impact → void dissolve → fade respawn.

enum PLAYER_STATE {
    ALIVE,
    DEATH
}

enum DEATH_SEQ {
    NONE,
    HURT,      // Hurt pose through heavy hitstop, then into dissolve
    HOLD,      // Linger on dissolve / void stain
    FADE_OUT,  // Cave darkens to void
    BLACK,     // Full black — teleport + camera snap
    FADE_IN    // Reveal at spawn
}

/// @function scr_player_death_fx_draw
/// @description Draw dissolve pixels + void stains after Bulb glow.
function scr_player_death_fx_draw() {
    with (obj_void_stain) {
        event_perform(ev_draw, 0);
    }
    with (obj_death_dissolve_pixel) {
        event_perform(ev_draw, 0);
    }
}

/// @function scr_player_death_fade_draw
/// @description Full-view void fade overlay (call last in post-draw).
function scr_player_death_fade_draw() {
    if (!instance_exists(obj_player)) return;
    with (obj_player) {
        if (!variable_instance_exists(id, "death_fade_alpha") || death_fade_alpha <= 0.001) exit;

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
        draw_set_alpha(clamp(death_fade_alpha, 0, 1));
        // Deep cave void — not pure black
        draw_set_color(make_color_rgb(6, 3, 12));
        draw_rectangle(_vx - 2, _vy - 2, _vx + _vw + 2, _vy + _vh + 2, false);

        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}

/// @function scr_player_death_ease
/// @description Smoothstep ease for fade alpha.
function scr_player_death_ease(_t) {
    _t = clamp(_t, 0, 1);
    return _t * _t * (3 - 2 * _t);
}

/// @function scr_camera_snap_to_player
/// @description Instantly center the view on the player (used under blackout).
function scr_camera_snap_to_player() {
    if (!instance_exists(obj_camera_controller) || !instance_exists(obj_player)) return;
    with (obj_camera_controller) {
        cam_look_ahead = 0;
        cam_shake_mag = 0;
        cam_shake_timer = 0;
        camera_prev_player_x = obj_player.x;
        camera_prev_player_y = obj_player.y;
        var _half_h = max(8, (obj_player.bbox_bottom - obj_player.bbox_top) * 0.5);
        var _max_x = max(global.camera_min_x, global.camera_max_x - cam_w);
        var _max_y = max(global.camera_min_y, global.camera_max_y - cam_h);
        var _sx = clamp(floor(obj_player.x - cam_w * 0.5), global.camera_min_x, _max_x);
        var _sy = clamp(floor(obj_player.y - _half_h - cam_h * 0.5), global.camera_min_y, _max_y);
        camera_set_view_pos(cam, _sx, _sy);
    }
    // Death freezes scr_camera_control — still realign mid_tiles so fade-in isn't empty/wrong.
    scr_parallax_update();
}

/// @function scr_player_clear_hurt_state
/// @description Wipe stun/hurt pose so respawn never resumes a leftover flinch.
function scr_player_clear_hurt_state() {
    stunTimer = 0;
    hurt_anim_tick = 0;
    hurt_is_air = false;
    hurt_air_landed = false;
    knockBackX = 0;
    knockBackY = 0;
}

/// @function scr_player_respawn
/// @description Restore player at spawn. Fade sequence keeps can_move locked until FADE_IN ends.
function scr_player_respawn(_unlock_move = true) {
    var _sx = variable_instance_exists(id, "DEATH_SPAWN_X") ? DEATH_SPAWN_X : 96;
    var _sy = variable_instance_exists(id, "DEATH_SPAWN_Y") ? DEATH_SPAWN_Y : 960;

    x = _sx;
    y = _sy;
    vsp = 0;
    hsp = 0;

    scr_player_clear_hurt_state();

    state = PLAYER_STATE.ALIVE;
    is_dying = false;
    // Keep death_is_dissolve true through fade-in so camera stays locked + sequence can finish.
    can_move = _unlock_move;
    grounded = false;

    obj_player_health = obj_player_health_max;
    invincible = true;
    invincibleTimer = INVINCIBILITY_FRAMES;
    blinkCounter = 0;

    visible = true;
    image_alpha = 1;
    image_blend = c_white;
    sprite_index = spr_mc_idle;
    image_index = 0;
    image_speed = 1;

    if (variable_instance_exists(id, "bulb_light") && bulb_light != undefined) {
        bulb_light.x = x;
        bulb_light.y = y + BULB_PLAYER_TORCH_Y_OFFSET;
        bulb_light.visible = true;
    }

    scr_camera_snap_to_player();
}

/// @function scr_player_death_burst_dissolve
/// @description End hurt pose: hide body, spray void pixels, leave floor stain, enter HOLD.
function scr_player_death_burst_dissolve() {
    // Freeze any leftover knockback from the killing blow
    hsp = 0;
    vsp = 0;
    scr_player_clear_hurt_state();

    visible = false;
    image_alpha = 0;

    var _bbox_w = max(8, bbox_right - bbox_left);
    var _bbox_h = max(8, bbox_bottom - bbox_top);
    var _layer = layer_exists("Particles") ? "Particles" : "Instances";
    var _cx = (bbox_left + bbox_right) * 0.5;
    var _feet = bbox_bottom;

    repeat (35) {
        var _px = x + random_range(-_bbox_w * 0.5, _bbox_w * 0.5);
        var _py = y + random_range(-_bbox_h, 0);

        var _p = instance_create_layer(_px, _py, _layer, obj_death_dissolve_pixel);
        _p.direction = random_range(60, 120);
        _p.speed = random_range(1, 5);
    }

    repeat (10) {
        var _mx = _cx + random_range(-_bbox_w * 0.4, _bbox_w * 0.4);
        var _my = _feet + random_range(-4, 2);
        var _m = instance_create_layer(_mx, _my, _layer, obj_death_dissolve_pixel);
        _m.direction = random_range(240, 300);
        _m.speed = random_range(0.4, 1.6);
        _m.gravity = 0.08;
        _m.life_max = random_range(40, 70);
        _m.life = _m.life_max;
        _m.col = make_color_rgb(18, 12, 24);
        _m.size = irandom_range(2, 4);
    }

    instance_create_layer(_cx, _feet, _layer, obj_void_stain);

    death_fade_alpha = 0;
    death_fade_phase = DEATH_SEQ.HOLD;
    death_seq_timer = variable_instance_exists(id, "DEATH_HOLD_FRAMES") ? DEATH_HOLD_FRAMES : 50;
}

/// @function scr_player_death_hurt_anim_step
/// @description Hold the first frame of spr_mc_hurt_air planted in place (no physics).
function scr_player_death_hurt_anim_step() {
    hsp = 0;
    vsp = 0;
    knockBackX = 0;
    knockBackY = 0;
    stunTimer = max(stunTimer, 2);

    visible = true;
    image_alpha = 1;
    image_blend = c_white;
    image_speed = 0;
    sprite_index = spr_mc_hurt_air;
    image_index = 0;
}

/// @function scr_player_death_sequence_step
/// @description Advance hurt → hold → fade out → black respawn → fade in.
function scr_player_death_sequence_step() {
    if (!death_is_dissolve) return;
    if (death_fade_phase == DEATH_SEQ.NONE) return;

    var _fout = variable_instance_exists(id, "DEATH_FADE_OUT_FRAMES") ? DEATH_FADE_OUT_FRAMES : 30;
    var _blk = variable_instance_exists(id, "DEATH_BLACK_FRAMES") ? DEATH_BLACK_FRAMES : 12;
    var _fin = variable_instance_exists(id, "DEATH_FADE_IN_FRAMES") ? DEATH_FADE_IN_FRAMES : 36;

    switch (death_fade_phase) {
        case DEATH_SEQ.HURT:
            // Always planted — no fall / knockback drift during the death flinch.
            hsp = 0;
            vsp = 0;
            knockBackX = 0;
            knockBackY = 0;

            // Heavy hitstop holds the first hurt frame; then advance hurt → dissolve.
            if (variable_global_exists("hitstop") && global.hitstop > 0) {
                sprite_index = spr_mc_hurt_air;
                image_index = 0;
                visible = true;
                image_alpha = 1;
                image_speed = 0;
                stunTimer = max(stunTimer, 2);
                break;
            }

            scr_player_death_hurt_anim_step();
            death_seq_timer--;
            if (death_seq_timer <= 0) {
                scr_player_death_burst_dissolve();
            }
            break;

        case DEATH_SEQ.HOLD:
            death_fade_alpha = 0;
            death_seq_timer--;
            if (death_seq_timer <= 0) {
                death_fade_phase = DEATH_SEQ.FADE_OUT;
                death_seq_timer = _fout;
            }
            break;

        case DEATH_SEQ.FADE_OUT: {
            death_seq_timer--;
            var _u = 1 - (death_seq_timer / max(1, _fout));
            death_fade_alpha = scr_player_death_ease(_u);
            if (death_seq_timer <= 0) {
                death_fade_alpha = 1;
                death_fade_phase = DEATH_SEQ.BLACK;
                death_seq_timer = _blk;
                scr_player_respawn(false);
            }
            break;
        }

        case DEATH_SEQ.BLACK:
            death_fade_alpha = 1;
            death_seq_timer--;
            if (death_seq_timer <= 0) {
                death_fade_phase = DEATH_SEQ.FADE_IN;
                death_seq_timer = _fin;
            }
            break;

        case DEATH_SEQ.FADE_IN: {
            death_seq_timer--;
            var _u_in = death_seq_timer / max(1, _fin);
            death_fade_alpha = scr_player_death_ease(_u_in);
            if (death_seq_timer <= 0) {
                death_fade_alpha = 0;
                death_fade_phase = DEATH_SEQ.NONE;
                death_is_dissolve = false;
                can_move = true;
                scr_player_clear_hurt_state();
                sprite_index = spr_mc_idle;
                image_index = 0;
                image_speed = 1;
                image_alpha = 1;
            }
            break;
        }
    }
}

/// @function scr_player_begin_death_dissolve
/// @description HP death: heavy hitstop + planted hurt anim, then void dissolve and fade respawn.
function scr_player_begin_death_dissolve() {
    if (state == PLAYER_STATE.DEATH) return;

    state = PLAYER_STATE.DEATH;
    is_dying = true;
    death_is_dissolve = true;
    can_move = false;

    // Plant immediately — no tumble into idle before dissolve.
    hsp = 0;
    vsp = 0;
    knockBackX = 0;
    knockBackY = 0;

    // Clear combat so nothing keeps swinging into the death hurt
    attacking = false;
    attack_lockout = 0;
    attack_commit_lock = 0;
    attack_recovery_lock = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
    attack_shift_remaining = 0;
    combo_buffer = false;
    comboTimer = 0;
    comboCount = 0;
    attack_priority_timer = 0;
    debug_hitbox_active = false;
    scr_player_saber_trail_clear();

    is_sprinting = false;
    sprint_committed = false;
    sprint_reel_active = false;
    sprint_reel_pending = false;

    // Death flinch always uses the first airborne frames of spr_mc_hurt_air.
    hurt_is_air = true;
    hurt_air_landed = false;
    hurt_anim_tick = 0;
    sprite_index = spr_mc_hurt_air;
    image_index = 0;
    image_speed = 0;
    image_alpha = 1;
    image_blend = c_white;
    visible = true;

    var _hurt = variable_instance_exists(id, "DEATH_HURT_FRAMES") ? DEATH_HURT_FRAMES : 28;
    var _hitstop = variable_instance_exists(id, "DEATH_HITSTOP_FRAMES") ? DEATH_HITSTOP_FRAMES : 22;
    stunTimer = max(_hurt, 2);
    death_seq_timer = _hurt;
    death_fade_alpha = 0;
    death_fade_phase = DEATH_SEQ.HURT;

    // Heavy impact freeze on the first hurt frame
    scr_hitstop_trigger(_hitstop);

    // Block further hits for the whole death sequence (no blink while dying)
    invincible = true;
    invincibleTimer = 9999;
    blinkCounter = 0;

    alarm[0] = -1;
}
