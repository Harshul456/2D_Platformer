/// @description obj_enemy body + crystal tint/rim (no debug). Call from Draw or over emissive glow.
function scr_enemy_crystal_light_init() {
    bulb_light = undefined;
    scr_enemy_hit_react_init();
    if (!BULB_ENEMY_CRYSTAL_LIGHT_ENABLED) return;
    if (!variable_global_exists("bulb_renderer") || global.bulb_renderer == undefined) return;

    crystal_kind = 0; // Pink crystal body — matches tile kind 0
    bulb_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
    scr_bulb_crystal_light_apply(id, BULB_ENEMY_LIGHT_SCALE);
}

/// @description Follow enemy + pulse BulbLight / spark phase (tile crystal parity).
function scr_enemy_crystal_light_step() {
    // Hit flare decay + light ripple animation tick every frame (even during hitstop).
    scr_enemy_hit_react_step();

    if (!BULB_ENEMY_CRYSTAL_LIGHT_ENABLED) return;
    if (bulb_light == undefined) return;

    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    var _y_off = BULB_ENEMY_LIGHT_Y_OFFSET;
    bulb_light.x = x;
    bulb_light.y = y + _y_off + _hover_y;
    bulb_light.visible = visible;

    scr_bulb_crystal_light_pulse_step(id);
    scr_enemy_hit_ripple_apply(); // Damped radius wave on top of breathe (water ripple)
    scr_crystal_spark_step(id);
}

/// @description Destroy enemy BulbLight on instance cleanup.
function scr_enemy_crystal_light_cleanup() {
    if (variable_instance_exists(id, "bulb_light") && bulb_light != undefined) {
        bulb_light.Destroy();
        bulb_light = undefined;
    }
}

/// @description Init hit-reaction state (emissive flare + light-ripple oscillation).
function scr_enemy_hit_react_init() {
    enemy_hit_glow = 0;
    hit_ripple_active = false;
    hit_ripple_age = 0;
    hit_ripple_strength = 0;
}

/// @description Spike the emissive flare and start the light source rippling (damped wave).
/// @param {Real} _strength Flare/ripple intensity multiplier (finishers pass more).
function scr_enemy_hit_react_trigger(_strength = 1) {
    if (!variable_instance_exists(id, "enemy_hit_glow")) enemy_hit_glow = 0;
    enemy_hit_glow = max(enemy_hit_glow, _strength);

    // Screen-space distortion shockwave centered on the enemy's core.
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    scr_hit_distort_add(x, y + BULB_ENEMY_LIGHT_Y_OFFSET + _hover_y, _strength);

    if (!BULB_ENEMY_HIT_RIPPLE_ENABLED) return;
    hit_ripple_active = true;
    hit_ripple_age = 0;
    hit_ripple_strength = _strength;
}

/// @description Decay the flare and advance the light-ripple oscillation. Self-guarded.
function scr_enemy_hit_react_step() {
    if (variable_instance_exists(id, "enemy_hit_glow") && enemy_hit_glow > 0) {
        enemy_hit_glow = max(0, enemy_hit_glow - BULB_ENEMY_HIT_GLOW_DECAY);
    }

    if (variable_instance_exists(id, "hit_ripple_active") && hit_ripple_active) {
        hit_ripple_age += 1;
        if (hit_ripple_age >= BULB_ENEMY_HIT_RIPPLE_LIFE) {
            hit_ripple_active = false;
            hit_ripple_age = 0;
        }
    }
}

/// @description Modulate the enemy light radius/intensity with a damped wave (water ripple).
/// Call AFTER the breathe pulse sets bulb_light.xscale/yscale each step.
function scr_enemy_hit_ripple_apply() {
    if (!variable_instance_exists(id, "hit_ripple_active") || !hit_ripple_active) return;
    if (bulb_light == undefined) return;

    var _life = BULB_ENEMY_HIT_RIPPLE_LIFE;
    // Exponentially-damped wave — natural water-surface settle (not a linear fade).
    var _env = exp(-BULB_ENEMY_HIT_RIPPLE_DAMP * hit_ripple_age);
    var _phase = hit_ripple_age * (BULB_ENEMY_HIT_RIPPLE_WAVES * 2 * pi / _life);
    var _osc = sin(_phase);        // starts at 0 (no pop), swells + contracts in waves
    var _amp = BULB_ENEMY_HIT_RIPPLE_AMPLITUDE * hit_ripple_strength;
    var _factor = 1 + _amp * _env * _osc;

    // Ripple is dominated by radius (shape) change; brightness barely moves (no flash).
    bulb_light.xscale *= _factor;
    bulb_light.yscale *= _factor;
    bulb_light.intensity *= (1 + _amp * BULB_ENEMY_HIT_RIPPLE_INTENSITY_MOD * _env * _osc);
}

/// @description Emissive draw alpha — driven by hit flare (resting base + spike on hit), not breathe.
function scr_enemy_glow_pulse_alpha() {
    var _hit = (variable_instance_exists(id, "enemy_hit_glow") ? enemy_hit_glow : 0);
    return clamp(BULB_ENEMY_GLOW_BASE + _hit * BULB_ENEMY_HIT_GLOW_BOOST, 0, 1);
}

/// @function scr_enemy_draw_lean_angle
/// @description Active procedural lean for draw calls (falls back to image_angle).
function scr_enemy_draw_lean_angle() {
    if (variable_instance_exists(id, "lean_angle")) return lean_angle;
    return image_angle;
}

/// @description Additive emissive overlay — spr_enemy_glow on top of spr_enemy (tiles_glow parity).
function scr_enemy_draw_emissive_glow() {
    if (!BULB_ENEMY_GLOW_ENABLED) return;
    if (variable_instance_exists(id, "state") && state == ENEMY_STATE.DEATH) return;

    var _glow_spr = scr_enemy_get_glow_sprite();
    if (!sprite_exists(_glow_spr)) return;

    // Same alpha source as scr_bulb_draw_glow_tile_layer → scr_bulb_crystal_glow_alpha_at.
    var _alpha = scr_enemy_glow_pulse_alpha() * BULB_ENEMY_GLOW_ALPHA * image_alpha;
    if (_alpha <= 0.01) return;

    var _shake_x = (variable_instance_exists(id, "telegraph_shake_x") ? telegraph_shake_x : 0);
    var _shake_y = (variable_instance_exists(id, "telegraph_shake_y") ? telegraph_shake_y : 0);
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    var _draw_x = floor(x + _shake_x);
    var _draw_y = floor(y + _shake_y) + _hover_y;
    var _xscale = scr_enemy_draw_xscale();
    var _lean = scr_enemy_draw_lean_angle();

    // Align glow origin to body sprite (spr_enemy_glow may use a different origin in the IDE).
    var _gx = _draw_x + sprite_get_xoffset(sprite_index) - sprite_get_xoffset(_glow_spr);
    var _gy = _draw_y + sprite_get_yoffset(sprite_index) - sprite_get_yoffset(_glow_spr);
    var _glow_img = clamp(floor(image_index), 0, sprite_get_number(_glow_spr) - 1);

    draw_set_alpha(_alpha);
    draw_sprite_ext(_glow_spr, _glow_img, _gx, _gy,
        _xscale, image_yscale, _lean, c_white, _alpha);
}

/// @description Draw all obj_enemy emissive overlays in Post Draw (after lit body redraw).
function scr_bulb_draw_enemy_emissive_glow_all() {
    if (!BULB_ENEMY_GLOW_ENABLED) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    camera_apply(_cam);

    var _old_tex = gpu_get_texfilter();
    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_add);
    draw_set_color(c_white);

    with (obj_enemy) {
        if (!visible) continue;
        scr_enemy_draw_emissive_glow();
    }

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

/// @description Brilliant white freeze-flash while the enemy is shattering.
function scr_enemy_draw_death_flash() {
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    var _dx = floor(x);
    var _dy = floor(y) + _hover_y;
    var _xs = scr_enemy_draw_xscale();
    var _lean = scr_enemy_draw_lean_angle();

    var _f = (variable_instance_exists(id, "death_flash_timer") && ENEMY_DEATH_FLASH_FRAMES > 0)
        ? clamp(death_flash_timer / ENEMY_DEATH_FLASH_FRAMES, 0, 1) : 1;
    var _puff = 1 + (1 - _f) * 0.18; // swell slightly right before the burst

    draw_sprite_ext(sprite_index, image_index, _dx, _dy,
        _xs * _puff, image_yscale * _puff, _lean, c_white, 1);

    var _ob = gpu_get_blendmode();
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(sprite_index, image_index, _dx, _dy,
        _xs * _puff, image_yscale * _puff, _lean, c_white, 0.85);
    gpu_set_blendmode(_ob);
}

/// @description Draw physics crystal shards (call in Bulb post-draw so fog/glow can't bury them).
function scr_enemy_shards_draw() {
    if (!instance_exists(obj_enemy_shard)) return;

    var _old_tex = gpu_get_texfilter();
    var _old_col = draw_get_color();
    var _old_alpha = draw_get_alpha();

    gpu_set_texfilter(false);
    with (obj_enemy_shard) {
        event_perform(ev_draw, 0);
    }
    gpu_set_texfilter(_old_tex);
    draw_set_color(_old_col);
    draw_set_alpha(_old_alpha);
}

function scr_enemy_draw_main_sprite() {
    if (variable_instance_exists(id, "state") && state == ENEMY_STATE.DEATH) {
        scr_enemy_draw_death_flash();
        return;
    }

    var _shake_x = (variable_instance_exists(id, "telegraph_shake_x") ? telegraph_shake_x : 0);
    var _shake_y = (variable_instance_exists(id, "telegraph_shake_y") ? telegraph_shake_y : 0);
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    var _draw_x = floor(x + _shake_x);
    // Add hover after floor so sub-pixel sine motion stays smooth on pixel-art sprites
    var _draw_y = floor(y + _shake_y) + _hover_y;

    var _draw_col = image_blend;
    if (variable_instance_exists(id, "gnd_state")) {
        if (gnd_state == GND_STATE_CHASE) _draw_col = merge_color(_draw_col, c_yellow, 0.18);
        else if (gnd_state == GND_STATE_ATTACK) _draw_col = merge_color(_draw_col, c_orange, 0.28);
        else if (gnd_state == GND_STATE_DAMAGED) _draw_col = merge_color(_draw_col, c_aqua, 0.22);
    }
    if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
        _draw_col = merge_color(_draw_col, c_red, 0.45);
    }
    var _crystal = undefined;
    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _crystal = scr_bulb_player_crystal_influence(x, y - 16);
        if (_crystal.strength > 0) {
            var _tint = global.bulb_renderer.normalMap ? 0.18 : 0.55;
            _draw_col = merge_colour(_draw_col, _crystal.blend, _crystal.strength * _tint);
        }
    }

    var _xscale = scr_enemy_draw_xscale();
    var _lean = scr_enemy_draw_lean_angle();

    draw_sprite_ext(sprite_index, image_index, _draw_x, _draw_y,
        _xscale, image_yscale, _lean, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined && global.bulb_renderer.normalMap) {
            var _wrap = { strength: _crystal.strength, blend: _crystal.blend, dir: (_crystal.dir + 180) mod 360 };
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x, _draw_y,
                _xscale, image_yscale, _wrap, image_alpha * 0.32);
        } else {
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x, _draw_y,
                _xscale, image_yscale, _crystal, image_alpha);
        }
    }
}

/// @description obj_enemy_parent body draw (state tint / hit blink).
function scr_enemy_parent_draw_main_sprite() {
    var _c = c_white;
    if (variable_instance_exists(id, "gnd_state")) {
        if (gnd_state == 1) _c = merge_color(c_white, c_yellow, 0.22);
        else if (gnd_state == 2) _c = merge_color(c_white, c_orange, 0.4);
        else if (gnd_state == 3) _c = merge_color(c_white, c_aqua, 0.28);
    }
    if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
        _c = merge_color(_c, c_red, 0.55);
    }

    var _draw_col = _c;
    var _crystal = undefined;
    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _crystal = scr_bulb_player_crystal_influence(x, y - 16);
        if (_crystal.strength > 0) {
            var _tint = global.bulb_renderer.normalMap ? 0.18 : 0.55;
            _draw_col = merge_colour(_draw_col, _crystal.blend, _crystal.strength * _tint);
        }
    }

    draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
        image_xscale, image_yscale, image_angle, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        scr_bulb_draw_crystal_rim(sprite_index, image_index, floor(x), floor(y),
            image_xscale, image_yscale, _crystal, image_alpha);
    }
}
