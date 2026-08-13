/// @description Waterfall on Tiles_Waterfall (tile 24 stream).
/// Native tilemap draw (correct depth). Y wrap-scroll = downward flow.
/// X stays world-locked by default so the column stays where you placed it
/// (matching mid parallax used the camera spawn as origin, which pushed the
/// waterfall off-screen when you walked over from the start of the room).

/// @description Init waterfall state on obj_bulb_controller.
function scr_waterfall_init(_controller) {
    with (_controller) {
        waterfall_layer_id = -1;
        waterfall_tilemap = -1;
        waterfall_scroll = 0;
        waterfall_start_x = 0;
        waterfall_start_y = 0;
        waterfall_tile_h = 32;
        waterfall_baked = false;
    }
}

/// @description Bind Tiles_Waterfall, pin depth in front of mid, remember authored offset.
function scr_waterfall_bake(_controller, _layer_name = BULB_WATERFALL_LAYER) {
    if (!BULB_WATERFALL_ENABLED) return;

    with (_controller) {
        // Clear old experiment hooks (do NOT wipe bake state via init).
        var _mid = layer_get_id("mid_tiles");
        if (_mid != -1) {
            layer_script_begin(_mid, scr_waterfall_layer_script_noop);
            layer_script_end(_mid, scr_waterfall_layer_script_noop);
        }
        var _fx = layer_get_id("WaterfallFX");
        if (_fx != -1) {
            layer_script_begin(_fx, scr_waterfall_layer_script_noop);
            layer_script_end(_fx, scr_waterfall_layer_script_noop);
            layer_destroy(_fx);
        }

        waterfall_layer_id = layer_get_id(_layer_name);
        waterfall_tilemap = -1;
        waterfall_scroll = 0;
        waterfall_start_x = 0;
        waterfall_start_y = 0;
        waterfall_tile_h = 32;
        waterfall_baked = false;
        if (waterfall_layer_id == -1) return;

        // Sit just in front of mid_tiles so the stream isn't hidden behind mid rock.
        if (_mid != -1) {
            layer_depth(waterfall_layer_id, layer_get_depth(_mid) - 1);
        }

        layer_set_visible(waterfall_layer_id, true);

        waterfall_start_x = layer_get_x(waterfall_layer_id);
        waterfall_start_y = layer_get_y(waterfall_layer_id);

        waterfall_tilemap = layer_tilemap_get_id(waterfall_layer_id);
        if (waterfall_tilemap != -1) {
            waterfall_tile_h = max(1, tilemap_get_tile_height(waterfall_tilemap));
        }

        waterfall_baked = true;
    }
}

/// @description No-op used to clear prior layer_script bindings.
function scr_waterfall_layer_script_noop() {
}

/// @description Advance downward scroll.
function scr_waterfall_step(_controller) {
    if (!BULB_WATERFALL_ENABLED) return;
    with (_controller) {
        // Never call scr_waterfall_init here — it would wipe the baked layer id
        // and freeze a bad layer_x, hiding the waterfall after you walk across the room.
        if (!variable_instance_exists(id, "waterfall_scroll")) waterfall_scroll = 0;
        if (!variable_instance_exists(id, "waterfall_baked")) waterfall_baked = false;
        waterfall_scroll += BULB_WATERFALL_SCROLL_SPEED;
    }
}

/// @description Apply X (optional mid match) + wrapped vertical scroll.
/// Call from scr_parallax_update after mid_tiles is updated.
function scr_waterfall_parallax_apply(_ctrl) {
    if (!BULB_WATERFALL_ENABLED) return;
    if (!instance_exists(obj_bulb_controller)) return;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "waterfall_baked") || !waterfall_baked) return;
        if (!variable_instance_exists(id, "waterfall_layer_id") || waterfall_layer_id == -1) return;

        if (BULB_WATERFALL_MATCH_MID_PARALLAX) {
            // Keep exact sync with mid's current offset (same speed / same origin).
            var _mid = layer_get_id("mid_tiles");
            if (_mid != -1 && variable_instance_exists(_ctrl, "mid_start_x")) {
                var _mid_dx = layer_get_x(_mid) - _ctrl.mid_start_x;
                layer_x(waterfall_layer_id, waterfall_start_x + _mid_dx);
            } else {
                var _cx = camera_get_view_x(_ctrl.cam) - _ctrl.parallax_cam_origin_x;
                layer_x(waterfall_layer_id, waterfall_start_x + (_cx * _ctrl.par_mid_x));
            }
        } else {
            // World-locked X — column stays where you authored it on the ledge.
            layer_x(waterfall_layer_id, waterfall_start_x);
        }

        // Wrap by one tile height so stacked 24s read as endless downward flow.
        var _th = max(1, waterfall_tile_h);
        var _off = waterfall_scroll mod _th;
        if (_off < 0) _off += _th;
        layer_y(waterfall_layer_id, waterfall_start_y + _off);
    }
}

/// @description Legacy no-ops (native layer draw).
function scr_waterfall_draw(_controller) {
}

function scr_waterfall_restore_front_layers(_lit_surface) {
}

function scr_waterfall_cache_free(_controller) {
}
