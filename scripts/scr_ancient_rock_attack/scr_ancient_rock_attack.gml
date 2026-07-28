/// @file scr_ancient_rock_attack.gml
/// @description Hover-in-place charge → imperfect homing bolt for obj_ancient_rock.

#macro ROCK_CHARGE_FRAMES          52
#macro ROCK_COOLDOWN_FRAMES        100
#macro ROCK_CHARGE_FLASH_HZ        0.28   // Blend flicker speed
#macro ROCK_CHARGE_MOTE_MAX        28
#macro ROCK_CHARGE_MOTE_RATE       1.35   // Motes per frame while charging
#macro ROCK_LIGHT_RELEASE_FRAMES   34     // Ease charged halo back to idle after fire
#macro ROCK_BOLT_SPEED             3.8
#macro ROCK_BOLT_DAMAGE            12
#macro ROCK_BOLT_KNOCK_X           4.0
#macro ROCK_BOLT_KNOCK_Y           -2.5
#macro ROCK_BOLT_RADIUS            7
#macro ROCK_BOLT_LIFE              420
#macro ROCK_BOLT_LIGHT_SCALE       0.55
#macro ROCK_BOLT_AIM_SPREAD        4     // Deg of launch aim noise (still aims at player once)

/// @description Init combat timers / charge mote pool (call from Create).
function scr_ancient_rock_attack_init() {
    air_hover_on_notice = true;
    gnd_touch_enabled = false;

    rock_cooldown = 20; // Brief delay before first shot after notice
    rock_charge_timer = 0;
    rock_charge_flash_t = random(100);
    rock_charge_motes = [];
    rock_charge_spawn_accum = 0;
    rock_charge_blend = c_white;
    rock_light_release = 0; // 1 → 0 ease after launch (charged halo settle)

    rock_bolt_damage = ROCK_BOLT_DAMAGE;
}

/// @description Face player without moving.
function scr_ancient_rock_face_player() {
    if (!instance_exists(obj_player)) return;
    var _dir = sign(obj_player.x - x);
    if (_dir == 0) _dir = (variable_instance_exists(id, "gnd_facing") ? gnd_facing : 1);
    gnd_facing = _dir;
    image_xscale = abs(image_xscale) * _dir;
}

/// @description Crystal core world position (teal diamond center + hover).
function scr_ancient_rock_core_xy() {
    var _hover = scr_enemy_floating_hover_draw_offset_y();
    return { x: x, y: y + BULB_ANCIENT_ROCK_CORE_Y_OFFSET + _hover };
}

/// @description Spawn a blue mote that drifts into the crystal core.
function scr_ancient_rock_charge_mote_create(_cx, _cy) {
    var _ang = random(360);
    var _r = random_range(22, 46);
    return {
        x: _cx + lengthdir_x(_r, _ang),
        y: _cy + lengthdir_y(_r, _ang) * 0.85,
        life: irandom_range(18, 34),
        max_life: 30,
        size: choose(1, 1, 2),
        pull: random_range(0.14, 0.22)
    };
}

function scr_ancient_rock_charge_motes_step(_charging) {
    var _core = scr_ancient_rock_core_xy();
    var _cx = _core.x;
    var _cy = _core.y;

    var _i = array_length(rock_charge_motes) - 1;
    while (_i >= 0) {
        var _m = rock_charge_motes[_i];
        _m.life -= 1;
        _m.x = lerp(_m.x, _cx, _m.pull);
        _m.y = lerp(_m.y, _cy, _m.pull);
        if (_m.life <= 0 || point_distance(_m.x, _m.y, _cx, _cy) < 3) {
            array_delete(rock_charge_motes, _i, 1);
        } else {
            rock_charge_motes[_i] = _m;
        }
        _i -= 1;
    }

    if (!_charging) {
        rock_charge_spawn_accum = 0;
        return;
    }

    if (array_length(rock_charge_motes) >= ROCK_CHARGE_MOTE_MAX) return;

    rock_charge_spawn_accum += ROCK_CHARGE_MOTE_RATE;
    while (rock_charge_spawn_accum >= 1 && array_length(rock_charge_motes) < ROCK_CHARGE_MOTE_MAX) {
        rock_charge_spawn_accum -= 1;
        array_push(rock_charge_motes, scr_ancient_rock_charge_mote_create(_cx, _cy));
    }
}

/// @description Apply charged/release Bulb halo (0 = idle breathe base already set, 1 = full charge).
function scr_ancient_rock_apply_light_boost(_t01) {
    if (bulb_light == undefined) return;
    _t01 = clamp(_t01, 0, 1);
    if (_t01 <= 0.001) return;

    var _boost = lerp(1.0, 1.85, _t01);
    bulb_light.intensity = BULB_ANCIENT_ROCK_LIGHT_INTENSITY * _boost;
    bulb_light.blend = merge_colour(BULB_ANCIENT_ROCK_LIGHT_BLEND, c_white, _t01 * 0.65);
    var _sc = enemy_bulb_light_scale * lerp(1.0, 1.22, _t01);
    bulb_light.xscale = 1.30 * _sc * _boost * 0.85;
    bulb_light.yscale = bulb_light.xscale;
}

/// @description Teal ↔ white flicker + Bulb brighten while charging.
function scr_ancient_rock_charge_visuals(_t01) {
    rock_charge_flash_t += ROCK_CHARGE_FLASH_HZ;
    var _flick = (dsin(rock_charge_flash_t * 360) + 1) * 0.5;
    // Escalate: early teal pulse → late hard white flashes
    var _teal = make_colour_rgb(40, 190, 210);
    var _hot = make_colour_rgb(210, 245, 255);
    var _pulse = merge_colour(_teal, _hot, clamp(_t01 * 0.55 + _flick * (0.45 + _t01 * 0.55), 0, 1));
    if (_t01 > 0.72 && (_flick > 0.55)) _pulse = c_white;
    rock_charge_blend = _pulse;
    image_blend = _pulse;

    if (variable_instance_exists(id, "telegraph_shake_x")) {
        var _shake = 0.6 + _t01 * 1.8;
        telegraph_shake_x = random_range(-_shake, _shake);
        telegraph_shake_y = random_range(-_shake * 0.6, _shake * 0.6);
    }

    scr_ancient_rock_apply_light_boost(_t01);

    if (variable_instance_exists(id, "enemy_hit_glow")) {
        enemy_hit_glow = max(enemy_hit_glow, 0.35 + _t01 * 0.9);
    }
}

function scr_ancient_rock_charge_visuals_reset() {
    image_blend = c_white;
    rock_charge_blend = c_white;
    if (variable_instance_exists(id, "telegraph_shake_x")) {
        telegraph_shake_x = 0;
        telegraph_shake_y = 0;
    }
}

/// @description Smoothly shrink the charged halo back to idle after launch.
function scr_ancient_rock_light_release_step() {
    if (!variable_instance_exists(id, "rock_light_release") || rock_light_release <= 0) return;

    // Ease-out settle into the small idle circle (smoothstep on remaining charge)
    var _t = clamp(rock_light_release, 0, 1);
    var _ease = _t * _t * (3 - 2 * _t);

    scr_ancient_rock_apply_light_boost(_ease);

    // Soft blend settle (no hard white snap)
    var _teal = make_colour_rgb(40, 190, 210);
    image_blend = merge_colour(c_white, _teal, _ease * 0.35);
    rock_charge_blend = image_blend;

    rock_light_release = max(0, rock_light_release - (1 / max(1, ROCK_LIGHT_RELEASE_FRAMES)));
    if (rock_light_release <= 0) {
        image_blend = c_white;
        rock_charge_blend = c_white;
    }
}

/// @description Fire one bolt aimed at the player — direction locks at launch (no homing).
function scr_ancient_rock_fire_bolt() {
    var _core = scr_ancient_rock_core_xy();
    var _tx = _core.x;
    var _ty = _core.y;
    if (instance_exists(obj_player)) {
        _tx = obj_player.x;
        // Aim at body center (origin is usually feet)
        _ty = (obj_player.bbox_top + obj_player.bbox_bottom) * 0.5;
    }

    var _layer = scr_hit_fx_layer();
    var _bolt = instance_create_layer(_core.x, _core.y, _layer, obj_ancient_rock_bolt);
    with (_bolt) {
        owner = other.id;
        damage = other.rock_bolt_damage;
        bolt_dir = point_direction(x, y, _tx, _ty);
        bolt_dir += random_range(-ROCK_BOLT_AIM_SPREAD, ROCK_BOLT_AIM_SPREAD);
        bolt_spd = ROCK_BOLT_SPEED;
    }

    // Distortion ripple + expanding blue Bulb light that fills the cave as the ring spreads
    scr_hit_distort_add(
        _core.x, _core.y,
        1.55,
        BULB_ANCIENT_ROCK_LIGHT_BLEND,
        3.4,   // brighter peak than default hit flash
        4.2,   // wider area light as the ripple expands
        0.85   // slower intensity falloff so the lit ring stays readable
    );
    scr_camera_trigger_shake(1.2, 6);
}

/// @description Combat step — call after air patrol. Hover-chase charges then fires.
function scr_ancient_rock_attack_step() {
    if (variable_global_exists("hitstop") && global.hitstop > 0) exit;
    if (!scr_time_scale_should_tick()) exit;
    if (!variable_instance_exists(id, "gnd_state")) exit;
    if (gnd_state == GND_STATE_DEAD || gnd_state == GND_STATE_DAMAGED) {
        rock_charge_timer = 0;
        rock_light_release = 0;
        scr_ancient_rock_charge_visuals_reset();
        scr_ancient_rock_charge_motes_step(false);
        exit;
    }

    // --- Charging / release ---
    if (gnd_state == GND_STATE_ATTACK) {
        hsp = 0;
        scr_ancient_rock_face_player();
        rock_light_release = 0;

        if (rock_charge_timer > 0) {
            rock_charge_timer -= 1;
            var _t01 = 1 - (rock_charge_timer / max(1, ROCK_CHARGE_FRAMES));
            scr_ancient_rock_charge_visuals(_t01);
            scr_ancient_rock_charge_motes_step(true);

            if (rock_charge_timer <= 0) {
                // Don't dump a bolt into a dead/respawning player
                if (scr_enemy_player_is_valid_combat_target()) {
                    scr_ancient_rock_fire_bolt();
                    rock_light_release = 1;
                } else {
                    scr_ancient_rock_charge_visuals_reset();
                    rock_light_release = 0;
                }
                // Keep charged halo peak, then ease down — no abrupt light snap
                if (variable_instance_exists(id, "telegraph_shake_x")) {
                    telegraph_shake_x = 0;
                    telegraph_shake_y = 0;
                }
                rock_cooldown = ROCK_COOLDOWN_FRAMES;
                // Stay engaged if player still in band; air patrol will set chase/patrol next frame
                gnd_state = GND_STATE_CHASE;
            }
        }
        exit;
    }

    scr_ancient_rock_charge_motes_step(false);
    scr_ancient_rock_light_release_step();

    if (rock_cooldown > 0) rock_cooldown -= 1;

    // Hover-chase → begin charge when ready
    if (gnd_state == GND_STATE_CHASE && rock_cooldown <= 0) {
        if (instance_exists(obj_player) && scr_enemy_player_is_valid_combat_target()) {
            gnd_state = GND_STATE_ATTACK;
            rock_charge_timer = ROCK_CHARGE_FRAMES;
            rock_charge_flash_t = random(50);
            rock_light_release = 0;
            telegraph_shake_x = 0;
            telegraph_shake_y = 0;
            hsp = 0;
            scr_ancient_rock_face_player();
        }
    } else if (gnd_state != GND_STATE_ATTACK && rock_light_release <= 0) {
        // Only hard-reset blend once release settle is done
        if (image_blend != c_white) image_blend = c_white;
    }
}

/// @description Additive charge motes (call from post-draw or enemy Draw).
function scr_ancient_rock_charge_motes_draw() {
    if (!variable_instance_exists(id, "rock_charge_motes")) return;
    var _n = array_length(rock_charge_motes);
    if (_n <= 0) return;

    var _old_a = draw_get_alpha();
    var _old_c = draw_get_color();
    var _old_b = gpu_get_blendmode();
    gpu_set_blendmode(bm_add);

    for (var _i = 0; _i < _n; _i++) {
        var _m = rock_charge_motes[_i];
        var _a = clamp(_m.life / max(1, _m.max_life), 0, 1);
        draw_set_alpha(0.35 + _a * 0.65);
        draw_set_color(merge_colour(BULB_ANCIENT_ROCK_LIGHT_BLEND, c_white, 1 - _a));
        var _px = floor(_m.x);
        var _py = floor(_m.y);
        var _s = _m.size;
        draw_rectangle(_px - _s, _py - _s, _px + _s, _py + _s, false);
    }

    gpu_set_blendmode(_old_b);
    draw_set_alpha(_old_a);
    draw_set_color(_old_c);
}

/// @description Draw all charging ancient rocks' inward motes.
function scr_ancient_rock_charge_motes_draw_all() {
    with (obj_ancient_rock) {
        scr_ancient_rock_charge_motes_draw();
    }
}

/// @description Draw all active rock bolts (post-draw so fog doesn't bury them).
function scr_ancient_rock_bolts_draw_all() {
    with (obj_ancient_rock_bolt) {
        scr_ancient_rock_bolt_draw();
    }
}

/// @description Advance bolt spin / pulse / spark shed (call from Step before move).
function scr_ancient_rock_bolt_anim_step() {
    bolt_age += 1;
    bolt_spin += bolt_spin_spd;
    bolt_pulse_t += 11;
    bolt_flicker += 17;

    // Age trail ghosts
    if (variable_instance_exists(id, "bolt_trail")) {
        var _ti = array_length(bolt_trail) - 1;
        while (_ti >= 0) {
            bolt_trail[_ti].life -= 1;
            if (bolt_trail[_ti].life <= 0) array_delete(bolt_trail, _ti, 1);
            _ti -= 1;
        }
    }

    // Orbiting / shedding sparkles
    if (!variable_instance_exists(id, "bolt_sparks")) bolt_sparks = [];
    var _si = array_length(bolt_sparks) - 1;
    while (_si >= 0) {
        var _s = bolt_sparks[_si];
        _s.life -= 1;
        _s.angle += _s.spin;
        _s.radius = max(0, _s.radius - _s.pull);
        _s.x = x + lengthdir_x(_s.radius, bolt_dir + 180 + _s.angle);
        _s.y = y + lengthdir_y(_s.radius, bolt_dir + 180 + _s.angle) * 0.7;
        if (_s.life <= 0) array_delete(bolt_sparks, _si, 1);
        else bolt_sparks[_si] = _s;
        _si -= 1;
    }

    bolt_spark_accum += 0.85;
    while (bolt_spark_accum >= 1 && array_length(bolt_sparks) < 14) {
        bolt_spark_accum -= 1;
        array_push(bolt_sparks, {
            angle: random(360),
            radius: random_range(6, 14),
            spin: random_range(-18, 18),
            pull: random_range(0.25, 0.55),
            life: irandom_range(8, 16),
            size: choose(1, 1, 2),
            x: x,
            y: y
        });
    }
}

/// @description Pixel diamond helper (filled, axis-aligned then we offset verts by spin via lengthdir).
function scr_ancient_rock_bolt_draw_diamond(_cx, _cy, _r, _ang, _col, _alpha) {
    draw_set_alpha(_alpha);
    draw_set_color(_col);
    var _x0 = _cx + lengthdir_x(_r, _ang);
    var _y0 = _cy + lengthdir_y(_r, _ang);
    var _x1 = _cx + lengthdir_x(_r * 0.62, _ang + 90);
    var _y1 = _cy + lengthdir_y(_r * 0.62, _ang + 90);
    var _x2 = _cx + lengthdir_x(_r, _ang + 180);
    var _y2 = _cy + lengthdir_y(_r, _ang + 180);
    var _x3 = _cx + lengthdir_x(_r * 0.62, _ang + 270);
    var _y3 = _cy + lengthdir_y(_r * 0.62, _ang + 270);
    draw_primitive_begin(pr_trianglefan);
    draw_vertex(_cx, _cy);
    draw_vertex(_x0, _y0);
    draw_vertex(_x1, _y1);
    draw_vertex(_x2, _y2);
    draw_vertex(_x3, _y3);
    draw_vertex(_x0, _y0);
    draw_primitive_end();
}

/// @description Animated bolt — spinning crystal, pulse glow, trail ghosts, shed sparks.
function scr_ancient_rock_bolt_draw() {
    var _px = floor(x);
    var _py = floor(y);
    var _old_b = gpu_get_blendmode();
    var _old_a = draw_get_alpha();
    var _old_c = draw_get_color();

    var _dir = variable_instance_exists(id, "bolt_dir") ? bolt_dir : 0;
    var _spin = variable_instance_exists(id, "bolt_spin") ? bolt_spin : 0;
    var _pulse = 0.5 + 0.5 * dsin(variable_instance_exists(id, "bolt_pulse_t") ? bolt_pulse_t : 0);
    var _flick = 0.55 + 0.45 * ((dsin(variable_instance_exists(id, "bolt_flicker") ? bolt_flicker : 0) + 1) * 0.5);
    var _teal = BULB_ANCIENT_ROCK_LIGHT_BLEND;
    var _cyan = make_colour_rgb(120, 220, 255);
    var _hot = make_colour_rgb(210, 245, 255);

    // --- Motion ribbon (segmented trail ghosts) ---
    gpu_set_blendmode(bm_add);
    if (variable_instance_exists(id, "bolt_trail")) {
        var _tn = array_length(bolt_trail);
        for (var _i = _tn - 1; _i >= 0; _i--) {
            var _t = bolt_trail[_i];
            var _ta = clamp(_t.life / 10, 0, 1) * (1 - _i / max(1, _tn));
            var _tr = lerp(2, ROCK_BOLT_RADIUS + 1, _ta) * (0.55 + _pulse * 0.2);
            scr_ancient_rock_bolt_draw_diamond(
                floor(_t.x), floor(_t.y),
                _tr, _spin - _i * 12,
                merge_colour(_teal, _cyan, _ta),
                0.18 + _ta * 0.35
            );
        }
    }

    // --- Long tapering streak behind flight ---
    var _streak = 18 + _pulse * 6;
    draw_set_alpha(0.25 + _pulse * 0.2);
    draw_set_color(_teal);
    draw_line_width(
        floor(_px - lengthdir_x(_streak, _dir)),
        floor(_py - lengthdir_y(_streak, _dir)),
        _px, _py, 4);
    draw_set_alpha(0.55);
    draw_set_color(_hot);
    draw_line_width(
        floor(_px - lengthdir_x(_streak * 0.55, _dir)),
        floor(_py - lengthdir_y(_streak * 0.55, _dir)),
        _px, _py, 2);

    // --- Soft outer halo (pulses) ---
    var _halo = ROCK_BOLT_RADIUS + 3 + _pulse * 3;
    draw_set_alpha(0.22 + _pulse * 0.2);
    draw_set_color(_teal);
    draw_circle(_px, _py, _halo, false);
    draw_set_alpha(0.4 + _flick * 0.25);
    draw_set_color(_cyan);
    draw_circle(_px, _py, ROCK_BOLT_RADIUS + 1, false);

    // --- Spinning crystal body (outer diamond + inner cross) ---
    scr_ancient_rock_bolt_draw_diamond(_px, _py, ROCK_BOLT_RADIUS + 1 + _pulse, _spin, _teal, 0.85);
    scr_ancient_rock_bolt_draw_diamond(_px, _py, ROCK_BOLT_RADIUS * 0.7, _spin + 45, _cyan, 0.9);
    // Tiny tip shards along flight axis
    var _tip = ROCK_BOLT_RADIUS + 4 + _pulse * 2;
    draw_set_alpha(0.9);
    draw_set_color(_hot);
    draw_line_width(
        floor(_px + lengthdir_x(2, _dir)),
        floor(_py + lengthdir_y(2, _dir)),
        floor(_px + lengthdir_x(_tip, _dir)),
        floor(_py + lengthdir_y(_tip, _dir)), 2);
    draw_line_width(
        floor(_px - lengthdir_x(2, _dir)),
        floor(_py - lengthdir_y(2, _dir)),
        floor(_px - lengthdir_x(_tip * 0.45, _dir)),
        floor(_py - lengthdir_y(_tip * 0.45, _dir)), 1);

    // --- Bright flickering core ---
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
    var _core = max(2, round(2 + _flick * 2));
    draw_rectangle(_px - _core, _py - _core, _px + _core, _py + _core, false);
    gpu_set_blendmode(bm_add);
    draw_set_alpha(0.7 * _flick);
    draw_set_color(_hot);
    draw_circle(_px, _py, _core + 1, false);

    // --- Shed / orbit sparks ---
    if (variable_instance_exists(id, "bolt_sparks")) {
        for (var _j = 0; _j < array_length(bolt_sparks); _j++) {
            var _sp = bolt_sparks[_j];
            var _sa = clamp(_sp.life / 16, 0, 1);
            draw_set_alpha(0.4 + _sa * 0.6);
            draw_set_color((_j mod 2 == 0) ? c_white : _cyan);
            var _sx = floor(_sp.x);
            var _sy = floor(_sp.y);
            var _ss = _sp.size;
            draw_rectangle(_sx - _ss + 1, _sy - _ss + 1, _sx + _ss - 1, _sy + _ss - 1, false);
        }
    }

    draw_set_alpha(_old_a);
    draw_set_color(_old_c);
    gpu_set_blendmode(_old_b);
}
