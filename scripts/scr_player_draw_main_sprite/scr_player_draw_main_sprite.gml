/// @description Player body + crystal tint/rim (no reflection). Call from Draw or over emissive glow.
function scr_player_draw_main_sprite() {
    var _draw_x = floor(x);
    var _draw_y = floor(y);
    var _wall_draw_nudge = 0;
    if (sprite_index == spr_mc_walljump && variable_instance_exists(id, "wall_side") && wall_side != 0) {
        _wall_draw_nudge = wall_side * WALL_CLING_DRAW_NUDGE_PX;
    }

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
        image_xscale, image_yscale, 0, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined && global.bulb_renderer.normalMap) {
            var _wrap = { strength: _crystal.strength, blend: _crystal.blend, dir: (_crystal.dir + 180) mod 360 };
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x + _wall_draw_nudge, _draw_y,
                image_xscale, image_yscale, _wrap, image_alpha * 0.32);
        } else {
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x + _wall_draw_nudge, _draw_y,
                image_xscale, image_yscale, _crystal, image_alpha);
        }
    }
}
