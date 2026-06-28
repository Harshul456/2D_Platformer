/// @description Draw a tile layer into Bulb's normal-map surface (flat up-facing normals per tile alpha).

/// @param {String} _layer_name

function scr_bulb_draw_tilemap_flat_normals(_layer_name) {

    var _layer = layer_get_id(_layer_name);

    if (_layer == -1) return;



    var _tm = layer_tilemap_get_id(_layer);

    if (_tm == -1) return;



    BulbNormalMapShaderSet(true);

    draw_tilemap(

        _tm,

        layer_get_x(_layer) + tilemap_get_x(_tm),

        layer_get_y(_layer) + tilemap_get_y(_tm)

    );

}



/// @description Rebuild Bulb normal-map surface (must run before renderer.Update).

/// @param {Struct.BulbRenderer} _renderer

function scr_bulb_draw_normal_map(_renderer) {

    if (_renderer == undefined || !_renderer.normalMap) return;



    var _cam = _renderer.GetCamera();



    surface_set_target(_renderer.GetNormalMapSurface());

    camera_apply(_cam);

    BulbNormalMapClear();



    scr_bulb_draw_tilemap_flat_normals("mid_tiles");

    scr_bulb_draw_tilemap_flat_normals("near_tiles");

    scr_bulb_draw_tilemap_flat_normals("lay_collision");

    scr_bulb_draw_tilemap_flat_normals("foreground");



    BulbNormalMapShaderSet(true);

    with (obj_enemy) {

        if (!visible) continue;

        BulbNormalMapDrawSelf();

    }



    // Player Laigter _n maps last so tile layers never overwrite them.

    with (obj_player) {

        if (!visible) continue;



        var _wall_nudge = 0;

        if (sprite_index == spr_mc_walljump && variable_instance_exists(id, "wall_side") && wall_side != 0) {

            _wall_nudge = wall_side * WALL_CLING_DRAW_NUDGE_PX;

        }



        scr_bulb_draw_laigter_normal(

            sprite_index,

            image_index,

            floor(x) + _wall_nudge,

            floor(y),

            image_xscale,

            image_yscale,

            0

        );

    }



    surface_reset_target();

    BulbNormalMapShaderReset();

}

