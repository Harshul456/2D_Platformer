/// @description How much a crystal BulbLight is affecting a world position.
/// @param {Real} _px
/// @param {Real} _py
/// @returns {Struct}
function scr_bulb_player_crystal_influence(_px, _py) {
    var _best_str = 0;
    var _best_blend = c_white;
    var _best_dir = 0;

    with (obj_bulb_crystal_light) {
        if (bulb_light == undefined) continue;

        var _reach = 96 * max(bulb_light.xscale, bulb_light.yscale);
        var _dist = point_distance(_px, _py, x, y);
        if (_dist >= _reach) continue;

        var _t = 1 - (_dist / _reach);
        _t = power(_t, 1.2);

        if (_t > _best_str) {
            _best_str = _t;
            _best_blend = bulb_light.blend;
            _best_dir = point_direction(x, y, _px, _py);
        }
    }

    with (obj_enemy) {
        if (bulb_light == undefined) continue;

        var _reach = 96 * max(bulb_light.xscale, bulb_light.yscale);
        var _dist = point_distance(_px, _py, bulb_light.x, bulb_light.y);
        if (_dist >= _reach) continue;

        var _t = 1 - (_dist / _reach);
        _t = power(_t, 1.2);

        if (_t > _best_str) {
            _best_str = _t;
            _best_blend = bulb_light.blend;
            _best_dir = point_direction(bulb_light.x, bulb_light.y, _px, _py);
        }
    }

    return { strength: _best_str, blend: _best_blend, dir: _best_dir };
}

/// @description Additive rim highlight toward nearest crystal (reads as light catching the body).
/// @param {Asset.GMSprite} _spr
/// @param {Real} _img
/// @param {Real} _dx
/// @param {Real} _dy
/// @param {Real} _xscale
/// @param {Real} _yscale
/// @param {Struct} _crystal Output from scr_bulb_player_crystal_influence
/// @param {Real} _alpha Base sprite alpha
function scr_bulb_draw_crystal_rim(_spr, _img, _dx, _dy, _xscale, _yscale, _crystal, _alpha) {
    if (_crystal.strength <= 0.05) return;

    var _rim_dist = 1;
    var _ox = lengthdir_x(_rim_dist, _crystal.dir);
    var _oy = lengthdir_y(_rim_dist, _crystal.dir);
    var _rim_alpha = _alpha * _crystal.strength * 0.24;

    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_spr, _img, _dx + _ox, _dy + _oy, _xscale, _yscale, 0, _crystal.blend, _rim_alpha);
    gpu_set_blendmode(bm_normal);
}

/// @description Emissive alpha for a glow tile — synced to the nearest crystal BulbLight pulse.
/// @param {Real} _px
/// @param {Real} _py
/// @param {Real} [_match_radius=24]
/// @returns {Real}
function scr_bulb_crystal_glow_alpha_at(_px, _py, _match_radius = 24) {
    var _best_alpha = undefined;
    var _best_dist = _match_radius;

    with (obj_bulb_crystal_light) {
        if (bulb_light == undefined) continue;
        if (!variable_instance_exists(id, "glow_pulse_alpha")) continue;

        var _d = point_distance(_px, _py, x, y);
        if (_d >= _best_dist) continue;

        _best_dist = _d;
        _best_alpha = glow_pulse_alpha;
    }

    with (obj_enemy) {
        if (bulb_light == undefined) continue;
        if (!variable_instance_exists(id, "glow_pulse_alpha")) continue;

        var _d = point_distance(_px, _py, bulb_light.x, bulb_light.y);
        if (_d >= _best_dist) continue;

        _best_dist = _d;
        _best_alpha = glow_pulse_alpha;
    }

    if (_best_alpha == undefined) {
        return lerp(BULB_GLOW_PULSE_MIN, BULB_GLOW_PULSE_MAX, 0.5);
    }

    return _best_alpha;
}
