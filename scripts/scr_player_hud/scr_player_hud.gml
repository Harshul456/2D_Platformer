/// @file scr_player_hud.gml
/// @description Player GUI — health bar (spr_mc_healthbar) top-left, drains cyan fill only.

/// @function scr_player_hud_init
/// @description Call from player Create. Tunables + smoothed display HP.
function scr_player_hud_init() {
    // GUI placement (display_set_gui_size 1280×720)
    HUD_HP_GUI_X = 16;
    HUD_HP_GUI_Y = 12;
    HUD_HP_SCALE = 2;

    // Sprite-space: ONLY the cyan/white strip BETWEEN the black outlines (y60 / y69).
    // Do not mask the black outline rows — those stay as the inner track.
    HUD_HP_FILL_L = 49;
    HUD_HP_FILL_T = 61;
    HUD_HP_FILL_B = 68;
    // Inclusive rightmost sprite-x to mask for each row y = FILL_T .. FILL_B
    HUD_HP_FILL_RIGHT = [99, 98, 97, 96, 95, 94, 93, 92];
    HUD_HP_EMPTY_COL = make_color_rgb(2, 5, 5); // match black gutter when drained
    HUD_HP_LERP = 0.2;         // Smooth chase toward real HP

    // Orb glow — GUI additive using Bulb's sLight128 + crystal breathe pulse
    // (BulbLight can't light Draw GUI; this matches the crystal in/out look on the HUD.)
    HUD_HP_ORB_SX = 37;        // Sprite-space orb center
    HUD_HP_ORB_SY = 64;
    HUD_HP_ORB_GLOW_BASE_SCALE = 0.42; // Halo size around the orb
    HUD_HP_ORB_GLOW_ALPHA = 0.85;
    HUD_HP_ORB_GLOW_COL = make_color_rgb(60, 235, 255);
    HUD_HP_ORB_GLOW_SPEED = 0.48; // Same ballpark as crystal glow_breathe_speed
    hud_orb_glow_time = random(360);

    // Blue HUD sparks — crystal-style swirl around the bar (GUI space)
    HUD_HP_SPARK_MAX = 11;
    HUD_HP_SPARK_RATE_MIN = 0.08;
    HUD_HP_SPARK_RATE_MAX = 0.2;
    HUD_HP_SPARK_ALPHA = 0.78;
    HUD_HP_SPARK_LIFE_MIN = 80;
    HUD_HP_SPARK_LIFE_MAX = 155;
    HUD_HP_SPARK_ORBIT_RX_MIN = 10; // Wide ellipse along the bar
    HUD_HP_SPARK_ORBIT_RX_MAX = 38;
    HUD_HP_SPARK_ORBIT_RY_MIN = 5;
    HUD_HP_SPARK_ORBIT_RY_MAX = 14;
    HUD_HP_SPARK_ORBIT_SPEED_MIN = 0.4;
    HUD_HP_SPARK_ORBIT_SPEED_MAX = 1.15;
    HUD_HP_SPARK_WOBBLE = 1.8;
    // Orbit center in sprite space (between orb and mid-bar)
    HUD_HP_SPARK_CX = 62;
    HUD_HP_SPARK_CY = 64;
    HUD_HP_SPARK_COLS = [
        make_color_rgb(227, 249, 251),
        make_color_rgb(62, 247, 236),
        make_color_rgb(20, 166, 213),
        make_color_rgb(96, 218, 244)
    ];
    hud_spark_list = [];
    hud_spark_spawn_accum = random(1);

    hud_hp_display = obj_player_health;
}

/// @function scr_player_hud_sync_health
/// @description Snap the displayed bar (respawn / full heal).
function scr_player_hud_sync_health() {
    if (!variable_instance_exists(id, "hud_hp_display")) return;
    hud_hp_display = obj_player_health;
}

/// @function scr_player_hud_spark_create
/// @description One blue mote orbiting the health bar (crystal spark pattern, GUI).
/// @returns {Struct}
function scr_player_hud_spark_create() {
    var _life = irandom_range(HUD_HP_SPARK_LIFE_MIN, HUD_HP_SPARK_LIFE_MAX);
    var _dir = choose(-1, 1);
    var _cols = HUD_HP_SPARK_COLS;
    return {
        angle: random(360),
        rx: random_range(HUD_HP_SPARK_ORBIT_RX_MIN, HUD_HP_SPARK_ORBIT_RX_MAX),
        ry: random_range(HUD_HP_SPARK_ORBIT_RY_MIN, HUD_HP_SPARK_ORBIT_RY_MAX),
        orbit_speed: random_range(HUD_HP_SPARK_ORBIT_SPEED_MIN, HUD_HP_SPARK_ORBIT_SPEED_MAX) * _dir,
        wobble_phase: random(360),
        wobble_amp: random_range(0.4, HUD_HP_SPARK_WOBBLE),
        twinkle_phase: random(360),
        life: _life,
        max_life: _life,
        col: _cols[irandom(array_length(_cols) - 1)],
        x: 0,
        y: 0
    };
}

/// @function scr_player_hud_spark_step
/// @description Advance HUD spark orbits (call once per GUI draw).
/// @param {Real} _cx Orbit center GUI x
/// @param {Real} _cy Orbit center GUI y
/// @param {Real} _sc HUD scale (widens ellipse with bar size)
/// @param {Real} _pulse 0–1 breathe phase
function scr_player_hud_spark_step(_cx, _cy, _sc, _pulse) {
    if (!variable_instance_exists(id, "hud_spark_list")) {
        hud_spark_list = [];
        hud_spark_spawn_accum = 0;
    }

    var _i = array_length(hud_spark_list) - 1;
    while (_i >= 0) {
        var _p = hud_spark_list[_i];
        _p.life -= 1;
        _p.angle += _p.orbit_speed;
        _p.wobble_phase += 5;
        _p.twinkle_phase += 11;

        var _w = dsin(_p.wobble_phase) * _p.wobble_amp * _sc;
        var _rx = _p.rx * _sc + _w;
        var _ry = _p.ry * _sc + _w * 0.55;
        _p.x = _cx + lengthdir_x(_rx, _p.angle);
        _p.y = _cy + lengthdir_y(_ry, _p.angle);

        if (_p.life <= 0) {
            array_delete(hud_spark_list, _i, 1);
        } else {
            hud_spark_list[_i] = _p;
        }
        _i -= 1;
    }

    if (array_length(hud_spark_list) >= HUD_HP_SPARK_MAX) return;

    var _spawn_rate = lerp(HUD_HP_SPARK_RATE_MIN, HUD_HP_SPARK_RATE_MAX, _pulse);
    hud_spark_spawn_accum += _spawn_rate;
    while (hud_spark_spawn_accum >= 1 && array_length(hud_spark_list) < HUD_HP_SPARK_MAX) {
        hud_spark_spawn_accum -= 1;
        array_push(hud_spark_list, scr_player_hud_spark_create());
    }
}

/// @function scr_player_hud_spark_draw
/// @description Additive blue pixel sparkles around the health bar.
/// @param {Real} _pulse Glow pulse alpha 0–1
function scr_player_hud_spark_draw(_pulse) {
    if (!variable_instance_exists(id, "hud_spark_list")) return;

    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    gpu_set_blendmode(bm_add);

    for (var _i = 0; _i < array_length(hud_spark_list); _i++) {
        var _p = hud_spark_list[_i];
        var _life_t = _p.life / _p.max_life;
        var _fade_in = min(1, (1 - _life_t) * 6);
        var _fade_out = min(1, _life_t * 3);
        var _twinkle = 0.45 + 0.55 * ((dsin(_p.twinkle_phase) + 1) * 0.5);
        var _a = _fade_in * _fade_out * _pulse * _twinkle * HUD_HP_SPARK_ALPHA;
        if (_a <= 0.01) continue;

        draw_set_alpha(_a);
        draw_set_color(_p.col);
        var _px = floor(_p.x);
        var _py = floor(_p.y);
        draw_rectangle(_px, _py, _px + 1, _py + 1, false);
        // Soft halo pixels for a fuller mote at HUD scale
        if (_a > 0.2) {
            draw_set_alpha(_a * 0.4);
            draw_rectangle(_px - 1, _py, _px - 1, _py, false);
            draw_rectangle(_px + 2, _py, _px + 2, _py, false);
            draw_rectangle(_px, _py - 1, _px + 1, _py - 1, false);
            draw_rectangle(_px, _py + 2, _px + 1, _py + 2, false);
        }
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(bm_normal);
}

/// @function scr_player_hud_orb_glow_draw
/// @description Crystal-style breathe glow on the health orb (additive sLight128).
/// @param {Real} _dx Healthbar sprite draw x (GUI)
/// @param {Real} _dy Healthbar sprite draw y (GUI)
/// @param {Real} _sc HUD scale
/// @param {Bool} _advance_pulse If true, step the breathe timer (call once per frame)
/// @param {Real} _size_mul Extra size multiplier (halo vs core overlay)
/// @param {Real} _alpha_mul Extra alpha multiplier
function scr_player_hud_orb_glow_draw(_dx, _dy, _sc, _advance_pulse = true, _size_mul = 1, _alpha_mul = 1) {
    if (!sprite_exists(sLight128)) return;

    if (_advance_pulse) hud_orb_glow_time += HUD_HP_ORB_GLOW_SPEED;
    var _t = (dsin(hud_orb_glow_time) + 1) * 0.5;

    var _pulse_scale = lerp(BULB_CRYSTAL_PULSE_SCALE_TIGHT, BULB_CRYSTAL_PULSE_SCALE_WIDE, _t);
    var _pulse_alpha = lerp(BULB_GLOW_PULSE_MIN, BULB_GLOW_PULSE_MAX, _t);
    var _ls = HUD_HP_ORB_GLOW_BASE_SCALE * _pulse_scale * _sc * _size_mul;
    var _ox = _dx + HUD_HP_ORB_SX * _sc;
    var _oy = _dy + HUD_HP_ORB_SY * _sc;
    var _a = HUD_HP_ORB_GLOW_ALPHA * _pulse_alpha * _alpha_mul;

    // Soft cookie (Bulb light sprite) — filter on for smooth bloom
    var _tf = gpu_get_texfilter();
    gpu_set_texfilter(true);
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(sLight128, 0, _ox, _oy, _ls, _ls, 0, HUD_HP_ORB_GLOW_COL, _a);
    draw_sprite_ext(sLight128, 0, _ox, _oy, _ls * 0.4, _ls * 0.4, 0, c_white, _a * 0.45);
    gpu_set_blendmode(bm_normal);
    gpu_set_texfilter(_tf);
}

/// @function scr_player_hud_draw
/// @description Draw GUI Event — frame + orb stay; only the center blue fill shortens with HP.
function scr_player_hud_draw() {
    if (!variable_instance_exists(id, "hud_hp_display")) return;
    if (!sprite_exists(spr_mc_healthbar)) return;

    // Hide under full death blackout (returns once fade-in starts)
    if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
        && variable_instance_exists(id, "death_fade_phase")
        && (death_fade_phase == DEATH_SEQ.FADE_OUT
            || death_fade_phase == DEATH_SEQ.BLACK)) {
        return;
    }

    var _max_hp = max(1, obj_player_health_max);
    var _target = clamp(obj_player_health, 0, _max_hp);
    hud_hp_display = lerp(hud_hp_display, _target, HUD_HP_LERP);
    if (abs(hud_hp_display - _target) < 0.4) hud_hp_display = _target;

    var _pct = clamp(hud_hp_display / _max_hp, 0, 1);
    var _spr = spr_mc_healthbar;
    var _sc = HUD_HP_SCALE;

    // Anchor visual content (opaque bbox) to top-left GUI padding
    var _dx = HUD_HP_GUI_X - sprite_get_bbox_left(_spr) * _sc;
    var _dy = HUD_HP_GUI_Y - sprite_get_bbox_top(_spr) * _sc;

    var _pulse_t = (dsin(hud_orb_glow_time) + 1) * 0.5;
    var _pulse_a = lerp(BULB_GLOW_PULSE_MIN, BULB_GLOW_PULSE_MAX, _pulse_t);

    // Wide halo behind the bar (shows around the orb), then bar art, then core pulse on top
    scr_player_hud_orb_glow_draw(_dx, _dy, _sc, true, 1.0, 1);

    gpu_set_texfilter(false);
    draw_sprite_ext(_spr, 0, _dx, _dy, _sc, _sc, 0, c_white, 1);

    // Brighten the gem itself so the breathe is obvious on the blue circle
    scr_player_hud_orb_glow_draw(_dx, _dy, _sc, false, 0.36, 0.7);

    if (_pct < 0.999) {
        // Mask drained fill row-by-row (includes top/bottom edge lines + slant tip).
        draw_set_color(HUD_HP_EMPTY_COL);
        draw_set_alpha(1);

        var _rows = HUD_HP_FILL_B - HUD_HP_FILL_T + 1;
        var _max_r = HUD_HP_FILL_RIGHT[0];
        for (var _ri = 1; _ri < array_length(HUD_HP_FILL_RIGHT); _ri++) {
            _max_r = max(_max_r, HUD_HP_FILL_RIGHT[_ri]);
        }
        var _span = _max_r - HUD_HP_FILL_L;
        var _cut_s = HUD_HP_FILL_L + _span * _pct;

        for (var _i = 0; _i < _rows; _i++) {
            var _right_s = HUD_HP_FILL_RIGHT[clamp(_i, 0, array_length(HUD_HP_FILL_RIGHT) - 1)];
            if (_cut_s > _right_s) continue;

            var _x1 = _dx + floor(_cut_s) * _sc;
            var _x2 = _dx + (_right_s + 1) * _sc;
            var _y1 = _dy + (HUD_HP_FILL_T + _i) * _sc;
            var _y2 = _y1 + _sc;
            draw_rectangle(_x1, _y1, _x2 - 0.01, _y2 - 0.01, false);
        }

        draw_set_color(c_white);
        draw_set_alpha(1);
    }

    // Blue motes swirling on an ellipse around the bar (crystal spark feel)
    var _spark_cx = _dx + HUD_HP_SPARK_CX * _sc;
    var _spark_cy = _dy + HUD_HP_SPARK_CY * _sc;
    scr_player_hud_spark_step(_spark_cx, _spark_cy, _sc, _pulse_t);
    scr_player_hud_spark_draw(_pulse_a);
}
