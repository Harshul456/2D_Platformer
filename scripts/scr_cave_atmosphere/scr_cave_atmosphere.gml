/// @description Init cave fog scroll state on obj_bulb_controller.
/// @param {Id.Instance} _controller
function scr_cave_atmosphere_init(_controller) {
    with (_controller) {
        fog_scroll_x = 0;
        fog_layer_start_x = 0;
        fog_layer_id = layer_get_id(BULB_CAVE_FOG_LAYER);
    }
}

/// @description Remember fog tile layer origin (Room Start) and hide from normal draw if present.
/// @param {Id.Instance} _controller
function scr_cave_atmosphere_bind_fog_layer(_controller) {
    with (_controller) {
        fog_layer_id = layer_get_id(BULB_CAVE_FOG_LAYER);
        if (fog_layer_id == -1) return;

        fog_layer_start_x = layer_get_x(fog_layer_id);
        layer_set_visible(fog_layer_id, false);
    }
}

/// @description Drift fog horizontally (procedural wisps + optional fog tile layer).
/// @param {Id.Instance} _controller
function scr_cave_fog_step(_controller) {
    if (!BULB_CAVE_FOG_ENABLED) return;

    with (_controller) {
        fog_scroll_x += BULB_CAVE_FOG_DRIFT_SPEED;

        if (fog_layer_id != -1) {
            layer_x(fog_layer_id, fog_layer_start_x + fog_scroll_x * BULB_CAVE_FOG_LAYER_PARALLAX);
        }
    }
}

/// @description Draw low cave mist in front of parallax walls, behind the player redraw.
/// @param {Id.Instance} _controller
function scr_cave_fog_draw(_controller) {
    if (!BULB_CAVE_FOG_ENABLED) return;

    with (_controller) {
        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) {
            _cam = obj_camera_controller.cam;
        }

        camera_apply(_cam);

        var _vx = camera_get_view_x(_cam);
        var _vy = camera_get_view_y(_cam);
        var _vw = camera_get_view_width(_cam);
        var _vh = camera_get_view_height(_cam);

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        gpu_set_texfilter(false);
        gpu_set_blendmode(bm_normal);
        draw_set_color(make_colour_rgb(BULB_CAVE_FOG_COL_R, BULB_CAVE_FOG_COL_G, BULB_CAVE_FOG_COL_B));

        // Optional painted fog tilemap (hide layer in Room Editor — drawn here after lighting).
        if (fog_layer_id != -1) {
            var _tm = layer_tilemap_get_id(fog_layer_id);
            if (_tm != -1) {
                draw_set_alpha(BULB_CAVE_FOG_TILE_ALPHA);
                draw_tilemap(
                    _tm,
                    layer_get_x(fog_layer_id) + tilemap_get_x(_tm),
                    layer_get_y(fog_layer_id) + tilemap_get_y(_tm)
                );
            }
        }

        // Procedural horizontal mist bands (works with or without a fog tile layer).
        var _band_step = BULB_CAVE_FOG_BAND_SPACING;
        var _band_h = BULB_CAVE_FOG_BAND_HEIGHT;
        var _start_band = floor((_vy - _band_step) / _band_step);

        for (var _b = _start_band; _b < _start_band + ceil(_vh / _band_step) + 2; _b++) {
            var _by = _b * _band_step;
            var _phase = _b * 0.61 + fog_scroll_x * 0.004;
            var _alpha = BULB_CAVE_FOG_ALPHA * (0.55 + 0.45 * ((dsin(_phase) + 1) * 0.5));
            draw_set_alpha(_alpha);

            var _chunk_w = BULB_CAVE_FOG_CHUNK_W;
            var _x0 = floor((_vx - fog_scroll_x) / _chunk_w) * _chunk_w + fog_scroll_x - _chunk_w;

            for (var _sx = _x0; _sx < _vx + _vw + _chunk_w; _sx += _chunk_w * 0.85) {
                var _wobble = dsin(_sx * 0.015 + _phase) * 6;
                var _w = _chunk_w * (0.55 + 0.35 * ((dsin(_sx * 0.031 + _phase * 1.7) + 1) * 0.5));
                draw_rectangle(
                    floor(_sx),
                    floor(_by + _wobble),
                    floor(_sx + _w),
                    floor(_by + _band_h + _wobble),
                    false
                );
            }
        }

        gpu_set_texfilter(_old_tex);
        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
    }
}

/// @description Soft dark screen-edge vignette (drawn after the player).
function scr_cave_vignette_draw() {
    if (!BULB_CAVE_VIGNETTE_ENABLED) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = camera_get_view_width(_cam);
    var _vh = camera_get_view_height(_cam);
    var _aspect = _vw / max(_vh, 1);

    static _u_strength = shader_get_uniform(shd_cave_vignette, "u_strength");
    static _u_softness = shader_get_uniform(shd_cave_vignette, "u_softness");
    static _u_aspect = shader_get_uniform(shd_cave_vignette, "u_aspect");

    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();
    var _old_tex = gpu_get_texfilter();

    gpu_set_texfilter(true);
    gpu_set_blendmode(bm_normal);
    draw_set_color(c_white);
    draw_set_alpha(1);

    shader_set(shd_cave_vignette);
    shader_set_uniform_f(_u_strength, BULB_CAVE_VIGNETTE_STRENGTH);
    shader_set_uniform_f(_u_softness, BULB_CAVE_VIGNETTE_SOFTNESS);
    shader_set_uniform_f(_u_aspect, _aspect);
    draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
    shader_reset();

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}
