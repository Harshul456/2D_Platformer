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
