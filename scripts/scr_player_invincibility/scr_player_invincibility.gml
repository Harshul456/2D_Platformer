/// @function scr_player_mote_burst
/// @description Crystal-style 1px motes — front spray + trailing wake.
/// @param {Real} _dir Dash/travel facing (-1 / 1)
/// @param {Array} _cols Additive colors to pick from
/// @param {Real} _count Total motes this burst
/// @param {Bool} [_trail_emit] If true, also arm a short trailing emit
function scr_player_mote_burst(_dir, _cols, _count, _trail_emit = true) {
    if (!variable_instance_exists(id, "dash_spark_list")) dash_spark_list = [];
    if (_dir == 0) _dir = 1;
    if (!is_array(_cols) || array_length(_cols) <= 0) _cols = [c_white];

    var _spd_lo = variable_instance_exists(id, "DASH_BURST_PARTICLE_SPEED_MIN")
        ? DASH_BURST_PARTICLE_SPEED_MIN : 1.6;
    var _spd_hi = variable_instance_exists(id, "DASH_BURST_PARTICLE_SPEED_MAX")
        ? DASH_BURST_PARTICLE_SPEED_MAX : 3.4;
    var _life_lo = variable_instance_exists(id, "DASH_BURST_PARTICLE_LIFE_MIN")
        ? DASH_BURST_PARTICLE_LIFE_MIN : 10;
    var _life_hi = variable_instance_exists(id, "DASH_BURST_PARTICLE_LIFE_MAX")
        ? DASH_BURST_PARTICLE_LIFE_MAX : 22;

    var _cx = (bbox_left + bbox_right) * 0.5;
    var _cy = (bbox_top + bbox_bottom) * 0.5;
    var _front = _dir;          // ahead of player
    var _wake = (_dir > 0) ? 180 : 0;

    var _max = 40;
    while (array_length(dash_spark_list) + _count > _max) {
        array_delete(dash_spark_list, 0, 1);
    }

    var _front_n = ceil(_count * 0.45);
    var _back_n = _count - _front_n;

    // Ahead of the player — burst forward, then settle into a trail as they dash through
    repeat (_front_n) {
        var _ang = (_front > 0)
            ? random_range(-40, 40)
            : random_range(140, 220);
        var _spd = random_range(_spd_lo * 0.85, _spd_hi);
        var _life = irandom_range(_life_lo, _life_hi);
        var _ox = _front * random_range(6, 16);
        array_push(dash_spark_list, {
            x: _cx + _ox + random_range(-2, 2),
            y: _cy + random_range(-11, 9),
            vx: lengthdir_x(_spd, _ang),
            vy: lengthdir_y(_spd, _ang) * 0.8,
            life: _life,
            max_life: _life,
            twinkle_phase: random(360),
            drag: random_range(0.86, 0.93),
            col: _cols[irandom(array_length(_cols) - 1)]
        });
    }

    // Trail behind — wake motes drifting opposite the dash
    repeat (_back_n) {
        var _ang = _wake + random_range(-50, 50);
        var _spd = random_range(_spd_lo, _spd_hi * 1.1);
        var _life = irandom_range(_life_lo, _life_hi);
        var _ox = -_front * random_range(2, 12);
        array_push(dash_spark_list, {
            x: _cx + _ox + random_range(-3, 3),
            y: _cy + random_range(-10, 8),
            vx: lengthdir_x(_spd, _ang),
            vy: lengthdir_y(_spd, _ang) * 0.85,
            life: _life,
            max_life: _life,
            twinkle_phase: random(360),
            drag: random_range(0.88, 0.94),
            col: _cols[irandom(array_length(_cols) - 1)]
        });
    }

    if (_trail_emit) {
        dash_spark_emit = variable_instance_exists(id, "DASH_BURST_TRAIL_FRAMES")
            ? DASH_BURST_TRAIL_FRAMES : 7;
        dash_spark_emit_dir = _dir;
        dash_spark_emit_cols = _cols;
    }
}

/// @function scr_player_dash_particles_burst
/// @description White crystal-style motes on dash activate (front + trailing wake).
function scr_player_dash_particles_burst() {
    var _dir = (variable_instance_exists(id, "sprint_commit_dir") && sprint_commit_dir != 0)
        ? sprint_commit_dir
        : last_direction;
    if (_dir == 0) _dir = sign(image_xscale);
    if (_dir == 0) _dir = 1;

    var _count = variable_instance_exists(id, "DASH_BURST_PARTICLE_COUNT")
        ? DASH_BURST_PARTICLE_COUNT : 12;
    var _cols = [c_white, make_color_rgb(230, 240, 255), make_color_rgb(200, 220, 255)];
    scr_player_mote_burst(_dir, _cols, _count, true);
}

/// @function scr_player_perfect_dodge_particle_colors
/// @returns {Array} Icy blues matching the Perfect Dodge focus circle.
function scr_player_perfect_dodge_particle_colors() {
    return [
        make_color_rgb(120, 200, 255),
        make_color_rgb(140, 220, 255),
        make_color_rgb(100, 190, 255),
        make_color_rgb(160, 230, 255),
        make_color_rgb(180, 240, 255)
    ];
}

/// @function scr_player_perfect_dodge_particles_burst
/// @description Opening icy blue burst on Perfect Dodge trigger (trail continues during flip).
function scr_player_perfect_dodge_particles_burst() {
    var _dir = (variable_instance_exists(id, "perfect_dodge_through_dir") && perfect_dodge_through_dir != 0)
        ? perfect_dodge_through_dir
        : last_direction;
    if (_dir == 0) _dir = sign(image_xscale);
    if (_dir == 0) _dir = 1;

    var _count = variable_instance_exists(id, "PERFECT_DODGE_PARTICLE_COUNT")
        ? PERFECT_DODGE_PARTICLE_COUNT : 10;
    // Opening pop only — continuous trail is driven by the flip step
    scr_player_mote_burst(_dir, scr_player_perfect_dodge_particle_colors(), _count, false);
}

/// @function scr_player_perfect_dodge_particles_trail
/// @description Emit blue motes while the flip animation coasts through the enemy.
function scr_player_perfect_dodge_particles_trail() {
    if (!variable_instance_exists(id, "dash_spark_list")) dash_spark_list = [];

    var _dir = (variable_instance_exists(id, "perfect_dodge_through_dir") && perfect_dodge_through_dir != 0)
        ? perfect_dodge_through_dir
        : last_direction;
    if (_dir == 0) _dir = sign(image_xscale);
    if (_dir == 0) _dir = 1;

    var _cols = scr_player_perfect_dodge_particle_colors();
    var _cx = (bbox_left + bbox_right) * 0.5;
    var _cy = (bbox_top + bbox_bottom) * 0.5;
    var _wake = (_dir > 0) ? 180 : 0;
    var _n = irandom_range(2, 3);

    repeat (_n) {
        var _ang = _wake + random_range(-45, 45);
        var _spd = random_range(1.0, 2.8);
        var _life = irandom_range(12, 22);
        array_push(dash_spark_list, {
            x: _cx - _dir * random_range(0, 10) + random_range(-3, 3),
            y: _cy + random_range(-12, 10),
            vx: lengthdir_x(_spd, _ang),
            vy: lengthdir_y(_spd, _ang) * 0.75 - random_range(0, 0.4),
            life: _life,
            max_life: _life,
            twinkle_phase: random(360),
            drag: random_range(0.9, 0.96),
            col: _cols[irandom(array_length(_cols) - 1)]
        });
    }

    while (array_length(dash_spark_list) > 48) {
        array_delete(dash_spark_list, 0, 1);
    }
}

/// @function scr_player_dash_particles_step
/// @description Advance mote drift / short trail emit after dash or Perfect Dodge.
function scr_player_dash_particles_step() {
    if (!variable_instance_exists(id, "dash_spark_list")) dash_spark_list = [];
    if (variable_global_exists("hitstop") && global.hitstop > 0) return;

    // Keep trailing a few frames after activate so motes stream behind the body
    if (variable_instance_exists(id, "dash_spark_emit") && dash_spark_emit > 0) {
        dash_spark_emit--;
        var _dir = variable_instance_exists(id, "dash_spark_emit_dir") ? dash_spark_emit_dir : last_direction;
        if (_dir == 0) _dir = 1;
        var _cols = (variable_instance_exists(id, "dash_spark_emit_cols") && is_array(dash_spark_emit_cols))
            ? dash_spark_emit_cols
            : [c_white];
        var _n = irandom_range(1, 3);
        var _cx = (bbox_left + bbox_right) * 0.5;
        var _cy = (bbox_top + bbox_bottom) * 0.5;
        var _wake = (_dir > 0) ? 180 : 0;
        repeat (_n) {
            var _ang = _wake + random_range(-35, 35);
            var _spd = random_range(1.2, 2.6);
            var _life = irandom_range(8, 16);
            array_push(dash_spark_list, {
                x: _cx - _dir * random_range(0, 8) + random_range(-2, 2),
                y: _cy + random_range(-9, 7),
                vx: lengthdir_x(_spd, _ang),
                vy: lengthdir_y(_spd, _ang) * 0.8,
                life: _life,
                max_life: _life,
                twinkle_phase: random(360),
                drag: random_range(0.9, 0.95),
                col: _cols[irandom(array_length(_cols) - 1)]
            });
        }
        while (array_length(dash_spark_list) > 40) {
            array_delete(dash_spark_list, 0, 1);
        }
    }

    for (var _i = array_length(dash_spark_list) - 1; _i >= 0; _i--) {
        var _p = dash_spark_list[_i];
        _p.life -= 1;
        _p.x += _p.vx;
        _p.y += _p.vy;
        _p.vx *= _p.drag;
        _p.vy *= _p.drag;
        _p.vy -= 0.02;
        _p.twinkle_phase += 14;

        if (_p.life <= 0) {
            array_delete(dash_spark_list, _i, 1);
        } else {
            dash_spark_list[_i] = _p;
        }
    }
}

/// @function scr_player_dash_particles_draw
/// @description Additive 1px motes (crystal spark look), drawn in Post-Draw in front of the scene.
function scr_player_dash_particles_draw() {
    if (!variable_instance_exists(id, "dash_spark_list")) return;
    if (array_length(dash_spark_list) <= 0) return;

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_blend = gpu_get_blendmode();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_add);

    var _alpha = variable_instance_exists(id, "DASH_BURST_PARTICLE_ALPHA")
        ? DASH_BURST_PARTICLE_ALPHA : 0.6;

    for (var _i = 0; _i < array_length(dash_spark_list); _i++) {
        var _p = dash_spark_list[_i];
        var _life_t = _p.life / max(1, _p.max_life);
        var _fade_in = min(1, (1 - _life_t) * 5);
        var _fade_out = min(1, _life_t * 2.5);
        var _twinkle = 0.4 + 0.6 * ((dsin(_p.twinkle_phase) + 1) * 0.5);
        var _a = _fade_in * _fade_out * _twinkle * _alpha;
        if (_a <= 0.02) continue;

        draw_set_alpha(_a);
        draw_set_color(variable_struct_exists(_p, "col") ? _p.col : c_white);
        var _px = floor(_p.x);
        var _py = floor(_p.y);
        draw_rectangle(_px, _py, _px, _py, false);
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
    gpu_set_texfilter(_old_tex);
}

/// @function scr_player_dash_iframes_begin
/// @description Grant silent dodge i-frames at dash start (no alpha blink).
function scr_player_dash_iframes_begin() {
    var _frames = (variable_instance_exists(id, "DASH_IFRAME_FRAMES") ? DASH_IFRAME_FRAMES : 10);
    dash_iframe_timer = max(dash_iframe_timer, _frames);
    if (variable_instance_exists(id, "perfect_dodge_used")) perfect_dodge_used = false;
    scr_player_dash_particles_burst();
}

/// @function scr_player_has_damage_iframes
/// @description True while hit invincibility, silent dash i-frames, or death sequence are active.
function scr_player_has_damage_iframes() {
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.DEATH) return true;
    // Fade respawn: ALIVE under black/fade — still block hits until control unlocks (no spawn blink).
    if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
        && variable_instance_exists(id, "death_fade_phase")
        && death_fade_phase != DEATH_SEQ.NONE) {
        return true;
    }
    if (variable_instance_exists(id, "invincible") && invincible) return true;
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) return true;
    return false;
}

function scr_player_invincibility() {
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) {
        dash_iframe_timer--;
    }

    // Death sequence owns visibility — never blink the hurt/dissolve body.
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.DEATH) {
        return;
    }
    if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
        && variable_instance_exists(id, "death_fade_phase")
        && death_fade_phase != DEATH_SEQ.NONE) {
        return;
    }

    if (invincible) {
        invincibleTimer--;
        blinkCounter++;

        if (blinkCounter >= blinkDelay) {
            if (image_alpha == 1) {
                image_alpha = 0.5;
            } else {
                image_alpha = 1;
            }
            blinkCounter = 0;
        }

        if (invincibleTimer <= 0) {
            invincible = false;
            image_alpha = 1;
        }
    }
}
