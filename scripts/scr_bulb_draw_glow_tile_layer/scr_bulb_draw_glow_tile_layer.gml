/// @description Additively draw the hidden glow-mask tile layer after Bulb lighting.
/// Each tile's brightness follows the nearest crystal BulbLight pulse (circle shrink = dimmer glow).
/// @param {String} [_layer_name]
function scr_bulb_draw_glow_tile_layer(_layer_name = BULB_GLOW_TILE_LAYER) {
    if (!BULB_GLOW_TILE_LAYER_ENABLED) return;

    var _layer = layer_get_id(_layer_name);
    if (_layer == -1) return;

    var _tm = layer_tilemap_get_id(_layer);
    if (_tm == -1) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    camera_apply(_cam);

    var _tw = tilemap_get_tile_width(_tm);
    var _th = tilemap_get_tile_height(_tm);
    var _w = tilemap_get_width(_tm);
    var _h = tilemap_get_height(_tm);
    var _ox = layer_get_x(_layer) + tilemap_get_x(_tm);
    var _oy = layer_get_y(_layer) + tilemap_get_y(_tm);
    var _match_r = max(_tw, _th) * 0.75;

    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();

    gpu_set_blendmode(bm_add);
    draw_set_color(c_white);

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _data = tilemap_get(_tm, _cx, _cy);
            if (_data == -1 || tile_get_empty(_data)) continue;

            var _tx = _ox + _cx * _tw;
            var _ty = _oy + _cy * _th;
            var _sample_x = _tx + _tw * 0.5;
            var _sample_y = _ty + _th * 0.48;

            draw_set_alpha(scr_bulb_crystal_glow_alpha_at(_sample_x, _sample_y, _match_r));
            draw_tile(BULB_GLOW_TILESET, _data, 0, _tx, _ty);
        }
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}
