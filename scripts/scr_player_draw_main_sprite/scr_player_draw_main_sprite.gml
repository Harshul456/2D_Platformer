/// @description Player body + crystal tint/rim (no reflection). Call from Draw or over emissive glow.

/// @function scr_player_texel_perfect_scale
/// @description Snap scale so sprite_dim * |scale| is a whole pixel count (no fractional texel stretch).
/// @param {Real} _scale Desired scale (may be negative for facing).
/// @param {Real} _sprite_dim Sprite width or height in pixels.
/// @returns {Real} Texel-snapped scale.
function scr_player_texel_perfect_scale(_scale, _sprite_dim) {
    if (_sprite_dim <= 0) return _scale;
    var _sign = sign(_scale);
    if (_sign == 0) _sign = 1;
    var _px = max(1, round(abs(_scale) * _sprite_dim));
    return _sign * (_px / _sprite_dim);
}

/// @function scr_player_land_squash_trigger
/// @description Punch landing squash from impact speed (call on airborne → grounded).
/// @param {Real} _impact_vsp Fall speed at land (positive down).
function scr_player_land_squash_trigger(_impact_vsp) {
    var _min_v = (variable_instance_exists(id, "LAND_SQUASH_MIN_VSP") ? LAND_SQUASH_MIN_VSP : 1.5);
    if (_impact_vsp < _min_v) return;

    var _ref = (variable_instance_exists(id, "LAND_SQUASH_VSP_REF") ? LAND_SQUASH_VSP_REF : 8);
    var _t = clamp(_impact_vsp / max(0.01, _ref), 0, 1);
    var _x0 = (variable_instance_exists(id, "LAND_SQUASH_X_MIN") ? LAND_SQUASH_X_MIN : 1.06);
    var _x1 = (variable_instance_exists(id, "LAND_SQUASH_X_MAX") ? LAND_SQUASH_X_MAX : 1.22);
    var _y0 = (variable_instance_exists(id, "LAND_SQUASH_Y_MAX") ? LAND_SQUASH_Y_MAX : 0.94);
    var _y1 = (variable_instance_exists(id, "LAND_SQUASH_Y_MIN") ? LAND_SQUASH_Y_MIN : 0.78);

    land_squash_x = lerp(_x0, _x1, _t);
    land_squash_y = lerp(_y0, _y1, _t);
    land_squash_timer = (variable_instance_exists(id, "LAND_SQUASH_FRAMES") ? LAND_SQUASH_FRAMES : 6);
}

/// @function scr_player_land_squash_step
/// @description Hold peak squash, then recover toward 1.
function scr_player_land_squash_step() {
    if (!variable_instance_exists(id, "land_squash_timer")) return;

    if (land_squash_timer > 0) {
        land_squash_timer--;
        return;
    }

    var _rec = (variable_instance_exists(id, "LAND_SQUASH_RECOVER") ? LAND_SQUASH_RECOVER : 0.28);
    land_squash_x = lerp(land_squash_x, 1, _rec);
    land_squash_y = lerp(land_squash_y, 1, _rec);
    if (abs(land_squash_x - 1) < 0.01) land_squash_x = 1;
    if (abs(land_squash_y - 1) < 0.01) land_squash_y = 1;
}

/// @function scr_player_jump_stretch_trigger
/// @description Tall/thin stretch when kicking into double-jump / wall-jump launch anim.
function scr_player_jump_stretch_trigger() {
    jump_stretch_x = (variable_instance_exists(id, "JUMP_STRETCH_X") ? JUMP_STRETCH_X : 0.88);
    jump_stretch_y = (variable_instance_exists(id, "JUMP_STRETCH_Y") ? JUMP_STRETCH_Y : 1.14);
    jump_stretch_timer = (variable_instance_exists(id, "JUMP_STRETCH_FRAMES") ? JUMP_STRETCH_FRAMES : 5);
    // Don't fight landing squash mid-air
    land_squash_x = 1;
    land_squash_y = 1;
    land_squash_timer = 0;
}

/// @function scr_player_jump_stretch_step
/// @description Hold peak stretch, then recover toward 1.
function scr_player_jump_stretch_step() {
    if (!variable_instance_exists(id, "jump_stretch_timer")) return;

    if (jump_stretch_timer > 0) {
        jump_stretch_timer--;
        return;
    }

    var _rec = (variable_instance_exists(id, "JUMP_STRETCH_RECOVER") ? JUMP_STRETCH_RECOVER : 0.22);
    jump_stretch_x = lerp(jump_stretch_x, 1, _rec);
    jump_stretch_y = lerp(jump_stretch_y, 1, _rec);
    if (abs(jump_stretch_x - 1) < 0.01) jump_stretch_x = 1;
    if (abs(jump_stretch_y - 1) < 0.01) jump_stretch_y = 1;
}

function scr_player_draw_main_sprite() {
    var _draw_x = floor(x);
    var _draw_y = floor(y);
    var _wall_draw_nudge = 0;
    if (sprite_index == spr_mc_walljump && variable_instance_exists(id, "wall_side") && wall_side != 0) {
        _wall_draw_nudge = wall_side * WALL_CLING_DRAW_NUDGE_PX;
    }

    // Texel-perfect draw scales (image_* already snapped in Step deform; re-snap for safety).
    var _sx = scr_player_texel_perfect_scale(image_xscale, sprite_get_width(sprite_index));
    var _sy = scr_player_texel_perfect_scale(image_yscale, sprite_get_height(sprite_index));

    var _draw_col = c_white;
    var _crystal = undefined;
    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _crystal = scr_bulb_player_crystal_influence(x, y - 16);
        if (_crystal.strength > 0) {
            var _tint = global.bulb_renderer.normalMap ? 0.18 : 0.55;
            _draw_col = merge_colour(c_white, _crystal.blend, _crystal.strength * _tint);
        }
    }

    draw_sprite_ext(sprite_index, image_index, _draw_x + _wall_draw_nudge, _draw_y,
        _sx, _sy, 0, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined && global.bulb_renderer.normalMap) {
            var _wrap = { strength: _crystal.strength, blend: _crystal.blend, dir: (_crystal.dir + 180) mod 360 };
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x + _wall_draw_nudge, _draw_y,
                _sx, _sy, _wrap, image_alpha * 0.32);
        } else {
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x + _wall_draw_nudge, _draw_y,
                _sx, _sy, _crystal, image_alpha);
        }
    }
}
