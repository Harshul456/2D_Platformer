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

/// @function scr_player_double_jump_whirl_begin
/// @description Start the circular whirl that rides the flip.
function scr_player_double_jump_whirl_begin() {
    double_jump_whirl_active = true;
    double_jump_whirl_t = 0;
    double_jump_whirl_angle = random(360);
    var _dir = (variable_instance_exists(id, "last_direction") && last_direction != 0)
        ? last_direction
        : sign(image_xscale);
    if (_dir == 0) _dir = 1;
    double_jump_whirl_dir = _dir;
}

/// @function scr_player_double_jump_whirl_step
/// @description Advance the whirl's spin and life with the flip.
function scr_player_double_jump_whirl_step() {
    if (!variable_instance_exists(id, "double_jump_whirl_active") || !double_jump_whirl_active) return;
    if (variable_global_exists("hitstop") && global.hitstop > 0) return;

    var _life = (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_LIFE") ? DOUBLE_JUMP_WHIRL_LIFE : 18);
    var _spin = (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_SPIN") ? DOUBLE_JUMP_WHIRL_SPIN : 22);
    double_jump_whirl_t++;
    double_jump_whirl_angle += _spin * double_jump_whirl_dir;
    if (double_jump_whirl_t >= _life) double_jump_whirl_active = false;
}

/// @function scr_player_double_jump_whirl_draw
/// @description Soft additive ring + orbiting 1px motes around the torso.
function scr_player_double_jump_whirl_draw() {
    if (!variable_instance_exists(id, "double_jump_whirl_active") || !double_jump_whirl_active) return;

    var _life = max(1, (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_LIFE") ? DOUBLE_JUMP_WHIRL_LIFE : 18));
    var _u = clamp(double_jump_whirl_t / _life, 0, 1);
    var _pop = min(1, double_jump_whirl_t / 3);
    var _fade = (1 - _u);
    _fade *= _fade;
    var _a = _pop * _fade * 0.8;
    if (_a <= 0.02) return;

    var _r0 = (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_RADIUS") ? DOUBLE_JUMP_WHIRL_RADIUS : 16);
    var _r1 = (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_RADIUS_END") ? DOUBLE_JUMP_WHIRL_RADIUS_END : 30);
    var _r = lerp(_r0, _r1, _u);
    var _n = (variable_instance_exists(id, "DOUBLE_JUMP_WHIRL_COUNT") ? DOUBLE_JUMP_WHIRL_COUNT : 12);
    var _cx = (bbox_left + bbox_right) * 0.5;
    var _cy = (bbox_top + bbox_bottom) * 0.5;
    var _cols = [c_white, make_color_rgb(230, 240, 255), make_color_rgb(200, 220, 255)];

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_blend = gpu_get_blendmode();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_add);

    // Soft double ring — reads as a whirl disk without a heavy filled circle.
    draw_set_alpha(_a * 0.28);
    draw_set_color(_cols[1]);
    draw_circle(_cx, _cy, _r, true);
    draw_circle(_cx, _cy, max(2, _r - 2), true);

    // Orbiting motes + short arc ghosts so the spin reads even at 1px.
    for (var _i = 0; _i < _n; _i++) {
        var _ang = double_jump_whirl_angle + (_i / max(1, _n)) * 360;
        var _rr = _r + dsin(_ang * 2 + double_jump_whirl_t * 18) * 2.5;
        var _px = floor(_cx + lengthdir_x(_rr, _ang));
        var _py = floor(_cy + lengthdir_y(_rr * 0.7, _ang));
        draw_set_alpha(_a * (0.55 + 0.45 * ((_i mod 2) == 0)));
        draw_set_color(_cols[_i mod array_length(_cols)]);
        draw_rectangle(_px, _py, _px, _py, false);

        var _ang_g = _ang - double_jump_whirl_dir * 16;
        var _gx = floor(_cx + lengthdir_x(_rr, _ang_g));
        var _gy = floor(_cy + lengthdir_y(_rr * 0.7, _ang_g));
        draw_set_alpha(_a * 0.22);
        draw_rectangle(_gx, _gy, _gx, _gy, false);
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
    gpu_set_texfilter(_old_tex);
}

/// @function scr_player_double_jump_particles_burst
/// @description Same crystal motes as dash, sprayed outward then arcing down under gravity.
///             Also starts the circular whirl that rides the flip.
function scr_player_double_jump_particles_burst() {
    if (!variable_instance_exists(id, "dash_spark_list")) dash_spark_list = [];
    scr_player_double_jump_whirl_begin();

    var _cols = [c_white, make_color_rgb(230, 240, 255), make_color_rgb(200, 220, 255)];
    var _count = variable_instance_exists(id, "DOUBLE_JUMP_PARTICLE_COUNT")
        ? DOUBLE_JUMP_PARTICLE_COUNT : 14;
    var _spd_lo = variable_instance_exists(id, "DOUBLE_JUMP_PARTICLE_SPEED_MIN")
        ? DOUBLE_JUMP_PARTICLE_SPEED_MIN : 1.8;
    var _spd_hi = variable_instance_exists(id, "DOUBLE_JUMP_PARTICLE_SPEED_MAX")
        ? DOUBLE_JUMP_PARTICLE_SPEED_MAX : 3.6;
    var _life_lo = variable_instance_exists(id, "DOUBLE_JUMP_PARTICLE_LIFE_MIN")
        ? DOUBLE_JUMP_PARTICLE_LIFE_MIN : 16;
    var _life_hi = variable_instance_exists(id, "DOUBLE_JUMP_PARTICLE_LIFE_MAX")
        ? DOUBLE_JUMP_PARTICLE_LIFE_MAX : 28;

    // Torso of the flip / double-jump pose (not feet)
    var _cx = (bbox_left + bbox_right) * 0.5;
    var _cy = (bbox_top + bbox_bottom) * 0.5;

    while (array_length(dash_spark_list) + _count > 48) {
        array_delete(dash_spark_list, 0, 1);
    }

    repeat (_count) {
        // Left / right outward cone with a slight upward kick → gravity curves the fall
        var _side = (irandom(1) == 0) ? -1 : 1;
        var _ang = (_side > 0) ? random_range(-55, 35) : random_range(145, 235);
        var _spd = random_range(_spd_lo, _spd_hi);
        var _life = irandom_range(_life_lo, _life_hi);
        var _up = random_range(0.9, 2.4);
        array_push(dash_spark_list, {
            x: _cx + _side * random_range(2, 10) + random_range(-2, 2),
            y: _cy + random_range(-6, 6),
            vx: lengthdir_x(_spd, _ang),
            vy: lengthdir_y(_spd, _ang) * 0.55 - _up,
            life: _life,
            max_life: _life,
            twinkle_phase: random(360),
            drag: random_range(0.95, 0.985),
            grav: random_range(0.14, 0.22),
            col: _cols[irandom(array_length(_cols) - 1)]
        });
    }
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
    scr_player_double_jump_whirl_step();
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
        if (variable_struct_exists(_p, "grav")) {
            _p.vy += _p.grav; // Double-jump arc — outward then fall
        } else {
            _p.vy -= 0.02; // Dash / PD motes float slightly
        }
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
    scr_player_double_jump_whirl_draw();
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
    scr_player_whoosh_sfx(false); // Same jump whoosh pool as ground jump
}

/// @function scr_player_has_damage_iframes
/// @description True while hit invincibility, silent dash i-frames, or death sequence are active.
function scr_player_has_damage_iframes() {
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.DEATH) return true;
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.CUTSCENE) return true;
    if (scr_cutscene_locks_player()) return true;
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
