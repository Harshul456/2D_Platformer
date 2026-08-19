/// @description Waterfall on Tiles_Waterfall (tile 24 stream).
/// Native tilemap draw. Y wrap-scroll = downward flow.
/// X is world-locked so the column stays where you authored it.
/// Depth sits just in front of mid so mid rock cannot bury it.
/// Optional: tile 24 painted on mid_tiles is moved onto Tiles_Waterfall at bake.
/// Ground splash particles use the tile-24 teal/lime palette.

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
        waterfall_splash_emitters = [];
        waterfall_splash_list = [];
        waterfall_side_streams = [];
        waterfall_side_foam = [];
        waterfall_soft_columns = [];
        waterfall_ground_sheets = [];
        waterfall_sfx_id = -1;
        waterfall_sfx_gain = 0;
    }
}

/// @description Copy stream tiles from mid onto Tiles_Waterfall, then clear mid copies.
function scr_waterfall_extract_stream_from_tilemap(_src, _dst) {
    if (_src == -1 || _dst == -1) return 0;

    var _w = min(tilemap_get_width(_src), tilemap_get_width(_dst));
    var _h = min(tilemap_get_height(_src), tilemap_get_height(_dst));
    var _count = 0;

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_src, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) != BULB_WATERFALL_TILE_STREAM) continue;
            tilemap_set(_dst, _td, _cx, _cy);
            tilemap_set(_src, 0, _cx, _cy);
            _count += 1;
        }
    }

    return _count;
}

function scr_waterfall_tilemap_has_stream(_tmap) {
    if (_tmap == -1) return false;
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_tmap, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) == BULB_WATERFALL_TILE_STREAM) return true;
        }
    }
    return false;
}

/// @description Pick a stream-green color (no pink/white — stays matching the waterfall).
function scr_waterfall_splash_pick_color() {
    var _roll = irandom(99);
    if (_roll < 30) {
        return make_colour_rgb(BULB_WATERFALL_COL_BASE_R, BULB_WATERFALL_COL_BASE_G, BULB_WATERFALL_COL_BASE_B);
    }
    if (_roll < 65) {
        return make_colour_rgb(BULB_WATERFALL_COL_MID_R, BULB_WATERFALL_COL_MID_G, BULB_WATERFALL_COL_MID_B);
    }
    return make_colour_rgb(BULB_WATERFALL_COL_BRIGHT_R, BULB_WATERFALL_COL_BRIGHT_G, BULB_WATERFALL_COL_BRIGHT_B);
}

/// @description Merge adjacent stream columns into splash pools + soft-stream rects.
function scr_waterfall_bake_splash_emitters(_tmap, _layer) {
    var _emitters = [];
    if (_tmap == -1) return _emitters;

    var _tw = tilemap_get_tile_width(_tmap);
    var _th = tilemap_get_tile_height(_tmap);
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    var _ox = layer_get_x(_layer) + tilemap_get_x(_tmap);
    var _oy = layer_get_y(_layer) + tilemap_get_y(_tmap);

    var _col_bottom = array_create(_w, -1);
    var _col_top = array_create(_w, -1);
    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_tmap, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) != BULB_WATERFALL_TILE_STREAM) continue;
            _col_bottom[_cx] = _cy;
            if (_col_top[_cx] < 0) _col_top[_cx] = _cy;
        }
    }

    var _cx = 0;
    while (_cx < _w) {
        if (_col_bottom[_cx] < 0) {
            _cx += 1;
            continue;
        }

        var _x0 = _cx;
        var _bot = _col_bottom[_cx];
        var _top = _col_top[_cx];
        while (_cx + 1 < _w && _col_bottom[_cx + 1] >= 0) {
            _cx += 1;
            if (_col_bottom[_cx] > _bot) _bot = _col_bottom[_cx];
            if (_col_top[_cx] >= 0 && (_top < 0 || _col_top[_cx] < _top)) _top = _col_top[_cx];
        }
        var _x1 = _cx;

        var _left = _ox + _x0 * _tw;
        var _right = _ox + (_x1 + 1) * _tw;
        var _stream_top = _oy + max(0, _top) * _th;
        var _stream_bottom = _oy + (_bot + 1) * _th;
        var _mid_x = (_left + _right) * 0.5;

        // Prefer pond surface first (splash only — no platform leak split).
        // Otherwise snap to a nearby collision floor for platform landings.
        var _splash_y = _stream_bottom;
        var _hits_pond = false;
        var _pond_y = scr_pond_surface_y_at(_mid_x);
        if (_pond_y != undefined && _stream_top < _pond_y + 4) {
            var _pond_dist = _pond_y - _stream_bottom;
            // Stream reaches / enters the pond, or ends just above it.
            if (_pond_dist <= BULB_WATERFALL_POND_SNAP && _pond_dist >= -_th * 3) {
                _splash_y = _pond_y;
                _hits_pond = true;
            }
        }
        if (!_hits_pond) {
            var _floor_y = scr_ceiling_drip_find_floor_y(_mid_x, max(0, _stream_bottom - _th));
            if (_floor_y != undefined && abs(_floor_y - _stream_bottom) <= _th * 2) {
                _splash_y = _floor_y;
            }
        }

        array_push(_emitters, {
            x: _mid_x,
            y: _splash_y,
            left: _left - BULB_WATERFALL_SPLASH_WIDTH_PAD,
            right: _right + BULB_WATERFALL_SPLASH_WIDTH_PAD,
            width: (_right - _left) + BULB_WATERFALL_SPLASH_WIDTH_PAD * 2,
            stream_left: _left,
            stream_right: _right,
            stream_top: _stream_top,
            stream_bottom: _splash_y,
            hits_pond: _hits_pond
        });

        _cx += 1;
    }

    return _emitters;
}

/// @description Bake sparkle dots/streaks for a stream column (main or side leak).
function scr_waterfall_bake_sparkles(_half, _h) {
    var _sparkles = [];
    if (!BULB_WATERFALL_SPARKLE_ENABLED) return _sparkles;

    var _inner_w = max(2, _half * 2 - 2);
    var _n = max(6, floor(_h * _inner_w * BULB_WATERFALL_SPARKLE_DENSITY));
    // Cap very tall void leaks so we don't spawn thousands of sparkles.
    _n = min(_n, 90);

    for (var _s = 0; _s < _n; _s++) {
        var _ox_max = max(0.5, _half - 1.5);
        array_push(_sparkles, {
            ox: random_range(-_ox_max, _ox_max),
            oy: random(_h),
            kind: (irandom(99) < 55) ? 0 : 1, // 0 = dot, 1 = short vertical streak
            len: irandom_range(2, 4),
            bright: (irandom(99) < 35)
        });
    }
    return _sparkles;
}

/// @description Draw scrolling sparkles inside a stream column.
function scr_waterfall_draw_sparkles(_cx, _y0, _y1, _sparkles, _scroll, _col_mid, _col_bri) {
    if (!BULB_WATERFALL_SPARKLE_ENABLED) return;
    if (_sparkles == undefined) return;

    var _hh = max(1, _y1 - _y0);
    for (var _si = 0; _si < array_length(_sparkles); _si++) {
        var _sp = _sparkles[_si];
        var _py = _y0 + ((_sp.oy + _scroll) mod _hh);
        var _px = floor(_cx + _sp.ox);

        draw_set_color(_sp.bright ? _col_bri : _col_mid);
        draw_set_alpha(BULB_WATERFALL_SPARKLE_ALPHA * (_sp.bright ? 0.9 : 0.65));

        if (_sp.kind == 0) {
            draw_rectangle(_px, floor(_py), _px, floor(_py), false);
        } else {
            var _len = min(_sp.len, _y1 - _py);
            if (_len >= 1) {
                draw_rectangle(_px, floor(_py), _px, floor(_py) + _len - 1, false);
            }
        }
    }
}

/// @description Soft translucent columns from splash emitter stream bounds.
function scr_waterfall_bake_soft_columns(_splash_emitters) {
    var _cols = [];
    if (_splash_emitters == undefined) return _cols;
    for (var _i = 0; _i < array_length(_splash_emitters); _i++) {
        var _em = _splash_emitters[_i];
        if (!variable_struct_exists(_em, "stream_left")) continue;

        var _half = max(3, (_em.stream_right - _em.stream_left) * 0.5);
        var _h = max(8, _em.stream_bottom - _em.stream_top);

        array_push(_cols, {
            left: _em.stream_left,
            right: _em.stream_right,
            y0: _em.stream_top,
            y1: _em.stream_bottom,
            cx: (_em.stream_left + _em.stream_right) * 0.5,
            half: _half,
            sparkles: scr_waterfall_bake_sparkles(_half, _h)
        });
    }
    return _cols;
}

/// @description Bind Tiles_Waterfall, pull mid copies, pin depth, bake splash points.
function scr_waterfall_bake(_controller, _layer_name = BULB_WATERFALL_LAYER) {
    if (!BULB_WATERFALL_ENABLED) return;

    with (_controller) {
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
        waterfall_splash_emitters = [];
        waterfall_splash_list = [];
        waterfall_side_streams = [];
        waterfall_side_foam = [];
        waterfall_soft_columns = [];
        waterfall_ground_sheets = [];
        scr_waterfall_sfx_stop(id);
        waterfall_sfx_id = -1;
        waterfall_sfx_gain = 0;
        if (waterfall_layer_id == -1) return;

        layer_script_begin(waterfall_layer_id, scr_waterfall_layer_script_noop);
        // All waterfall visuals draw on this layer (behind Instances / player).
        layer_script_end(waterfall_layer_id, scr_waterfall_layer_draw_soft);

        waterfall_tilemap = layer_tilemap_get_id(waterfall_layer_id);
        if (waterfall_tilemap == -1) return;

        if (_mid != -1) {
            var _mid_tmap = layer_tilemap_get_id(_mid);
            if (_mid_tmap != -1) {
                scr_waterfall_extract_stream_from_tilemap(_mid_tmap, waterfall_tilemap);
            }
        }

        if (!scr_waterfall_tilemap_has_stream(waterfall_tilemap)) return;

        waterfall_tile_h = max(1, tilemap_get_tile_height(waterfall_tilemap));

        if (_mid != -1) {
            // Just in front of mid rock, still well behind Instances (player).
            layer_depth(waterfall_layer_id, layer_get_depth(_mid) - 1);
        }

        // Guarantee behind the actor layer so the player always reads in front of the water.
        var _actors = layer_get_id("Instances");
        if (_actors != -1) {
            var _behind_player = layer_get_depth(_actors) + 80;
            if (layer_get_depth(waterfall_layer_id) < _behind_player) {
                layer_depth(waterfall_layer_id, _behind_player);
            }
        }

        // Only place ponds relative to the waterfall when there's no lay_collision to
        // mask their wall-seam overlap (scr_pond_bake pins them behind it otherwise).
        if (layer_get_id("lay_collision") == -1
            && variable_instance_exists(id, "pond_layer_id") && pond_layer_id != -1) {
            layer_depth(pond_layer_id, layer_get_depth(waterfall_layer_id) + 1);
        }

        waterfall_start_x = layer_get_x(waterfall_layer_id);
        waterfall_start_y = layer_get_y(waterfall_layer_id);
        layer_x(waterfall_layer_id, waterfall_start_x);
        layer_y(waterfall_layer_id, waterfall_start_y);

        if (BULB_WATERFALL_SPLASH_ENABLED || BULB_WATERFALL_SOFT_STREAM || BULB_WATERFALL_LEAK_ENABLED) {
            waterfall_splash_emitters = scr_waterfall_bake_splash_emitters(waterfall_tilemap, waterfall_layer_id);
        }
        if (BULB_WATERFALL_SOFT_STREAM) {
            waterfall_soft_columns = scr_waterfall_bake_soft_columns(waterfall_splash_emitters);
            // Remove zig-zag tiles; soft columns draw in the layer script instead.
            scr_waterfall_clear_stream_tiles(waterfall_tilemap);
        }
        if (BULB_WATERFALL_LEAK_ENABLED) {
            waterfall_side_streams = scr_waterfall_bake_side_streams(waterfall_splash_emitters);
            waterfall_ground_sheets = scr_waterfall_bake_ground_sheets(waterfall_splash_emitters);
        }

        layer_set_visible(waterfall_layer_id, true);

        waterfall_baked = true;
        scr_waterfall_sfx_start(id);
    }
}

function scr_waterfall_layer_script_noop() {
}

/// @description Draw soft translucent main columns + sparkles at Tiles_Waterfall depth.
/// Splash / side leaks also draw here so the player (Instances) stays visually in front.
function scr_waterfall_layer_draw_soft() {
    if (!instance_exists(obj_bulb_controller)) return;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "waterfall_baked") || !waterfall_baked) return;
        if (!variable_instance_exists(id, "waterfall_soft_columns")) waterfall_soft_columns = [];
        if (!variable_instance_exists(id, "waterfall_splash_list")) waterfall_splash_list = [];
        if (!variable_instance_exists(id, "waterfall_splash_emitters")) waterfall_splash_emitters = [];
        if (!variable_instance_exists(id, "waterfall_side_streams")) waterfall_side_streams = [];
        if (!variable_instance_exists(id, "waterfall_side_foam")) waterfall_side_foam = [];
        if (!variable_instance_exists(id, "waterfall_scroll")) waterfall_scroll = 0;
        if (!variable_instance_exists(id, "waterfall_ground_sheets")) waterfall_ground_sheets = [];

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        var _col_base = make_colour_rgb(BULB_WATERFALL_COL_BASE_R, BULB_WATERFALL_COL_BASE_G, BULB_WATERFALL_COL_BASE_B);
        var _col_mid = make_colour_rgb(BULB_WATERFALL_COL_MID_R, BULB_WATERFALL_COL_MID_G, BULB_WATERFALL_COL_MID_B);
        var _col_bri = make_colour_rgb(BULB_WATERFALL_COL_BRIGHT_R, BULB_WATERFALL_COL_BRIGHT_G, BULB_WATERFALL_COL_BRIGHT_B);

        // --- Main soft stream body ---
        if (BULB_WATERFALL_SOFT_STREAM) {
            gpu_set_texfilter(true);
            gpu_set_blendmode(bm_normal);
            var _a_main = BULB_WATERFALL_SOFT_ALPHA;

            for (var _ci = 0; _ci < array_length(waterfall_soft_columns); _ci++) {
                var _col = waterfall_soft_columns[_ci];
                var _half = _col.half + BULB_WATERFALL_SOFT_EDGE * 0.25;
                // Flush foot so the column meets the splash / floor (no empty gap).
                scr_waterfall_draw_soft_stream(_col.cx, _col.y0, _col.y1, _half, _col_base, _a_main, true);
                scr_waterfall_draw_soft_stream(_col.cx, _col.y0 + 2, _col.y1, max(2, _half - 2), _col_mid, _a_main * 0.55, true);

                // Soft bright rim edges (like the reference stream borders).
                draw_set_color(_col_bri);
                draw_set_alpha(_a_main * 0.45);
                draw_rectangle(_col.cx - _half, _col.y0 + 2, _col.cx - _half + 1, _col.y1, false);
                draw_rectangle(_col.cx + _half - 1, _col.y0 + 2, _col.cx + _half, _col.y1, false);

                // Interior core wash (no horizontal stripes).
                draw_set_alpha(_a_main * 0.32);
                draw_rectangle(_col.cx - max(1, _half * 0.28), _col.y0 + 4, _col.cx + max(1, _half * 0.28), _col.y1, false);
            }

            // Tiny scrolling dots / short vertical streaks inside the stream.
            if (BULB_WATERFALL_SPARKLE_ENABLED) {
                gpu_set_texfilter(false);
                // Normal blend keeps sparkles stream-green (additive + cave purple → pink).
                gpu_set_blendmode(bm_normal);
                var _scroll = waterfall_scroll * BULB_WATERFALL_SPARKLE_SCROLL;

                for (var _cj = 0; _cj < array_length(waterfall_soft_columns); _cj++) {
                    var _c2 = waterfall_soft_columns[_cj];
                    if (!variable_struct_exists(_c2, "sparkles")) continue;
                    scr_waterfall_draw_sparkles(_c2.cx, _c2.y0, _c2.y1, _c2.sparkles, _scroll, _col_mid, _col_bri);
                }
            }
        }

        // --- Splash foam (rounder bubble mound pouring into leaks) ---
        if (BULB_WATERFALL_SPLASH_ENABLED) {
            gpu_set_texfilter(true);
            gpu_set_blendmode(bm_normal);

            // Soft elliptical foam base under particles (rounds the overall splash silhouette).
            for (var _e = 0; _e < array_length(waterfall_splash_emitters); _e++) {
                var _em = waterfall_splash_emitters[_e];
                var _cx = (_em.left + _em.right) * 0.5;
                var _rx = max(8, (_em.right - _em.left) * 0.48);
                var _ry = BULB_WATERFALL_SPLASH_HEIGHT * 0.55;
                draw_set_color(_col_base);
                draw_set_alpha(0.28);
                draw_ellipse(_cx - _rx, _em.y - _ry, _cx + _rx, _em.y + 2, false);
                draw_set_color(_col_mid);
                draw_set_alpha(0.2);
                draw_ellipse(_cx - _rx * 0.72, _em.y - _ry * 1.05, _cx + _rx * 0.72, _em.y + 1, false);
            }

            for (var _i = 0; _i < array_length(waterfall_splash_list); _i++) {
                var _p = waterfall_splash_list[_i];
                var _t = clamp(_p.life / max(1, _p.life_max), 0, 1);
                var _a = BULB_WATERFALL_SPLASH_ALPHA * (0.4 + 0.6 * _t);
                var _r = max(2, _p.size);
                draw_set_color(_p.color);
                draw_set_alpha(_a * 0.55);
                // Soft outer halo → reads as a rounder bubble.
                draw_circle(_p.x, _p.y, _r + 1.2, false);
                draw_set_alpha(_a);
                draw_circle(_p.x, _p.y, _r, false);
                if (_r >= 2.5) {
                    draw_set_color(_col_bri);
                    draw_set_alpha(_a * 0.5);
                    draw_circle(_p.x - _r * 0.22, _p.y - _r * 0.28, max(1, _r * 0.38), false);
                }
            }
        }

        // --- Side leaks + ground sheet (rounded pour into leaks) ---
        if (BULB_WATERFALL_LEAK_ENABLED) {
            gpu_set_texfilter(true);
            gpu_set_blendmode(bm_normal);

            // Moving sheet on the ledge — flows left/right into the leaks.
            var _gs_scroll = waterfall_scroll * BULB_WATERFALL_SPARKLE_SCROLL;
            for (var _gi = 0; _gi < array_length(waterfall_ground_sheets); _gi++) {
                scr_waterfall_draw_ground_sheet(waterfall_ground_sheets[_gi], _gs_scroll, _col_base, _col_mid, _col_bri);
            }

            for (var _li = 0; _li < array_length(waterfall_side_streams); _li++) {
                var _st = waterfall_side_streams[_li];
                var _lcx = _st.x + _st.width * 0.5;
                var _lhalf = max(2, _st.width * 0.5);
                var _y_top = _st.y0;
                var _y2 = _st.y1;
                if (_y2 <= _y_top) continue;

                var _a = BULB_WATERFALL_LEAK_ALPHA;
                var _flush = variable_struct_exists(_st, "on_floor") ? !_st.on_floor : true;
                var _pour_r = BULB_WATERFALL_LEAK_POUR_R;

                // Round pour lobe where the ground sheet tips into the leak.
                draw_set_color(_col_mid);
                draw_set_alpha(_a * 0.95);
                draw_circle(_lcx, _st.y_splash - 1, _pour_r + 1, false);
                draw_set_color(_col_bri);
                draw_set_alpha(_a * 0.55);
                draw_circle(_lcx + _st.side * 1.2, _st.y_splash + 1, _pour_r * 0.75, false);
                draw_set_color(_col_base);
                draw_set_alpha(_a * 0.7);
                draw_circle(_lcx, _st.y_splash + 3, max(3, _lhalf + 1), false);

                // Flush column under the round pour.
                scr_waterfall_draw_soft_stream(_lcx, _y_top + 2, _y2, _lhalf, _col_base, _a, _flush, true);
                scr_waterfall_draw_soft_stream(_lcx, _y_top + 2, _y2, max(1.5, _lhalf - 1.5), _col_mid, _a * 0.65, _flush, true);
            }

            // Same sparkle dots/streaks as the main stream, scrolling down the leaks.
            if (BULB_WATERFALL_SPARKLE_ENABLED) {
                gpu_set_texfilter(false);
                gpu_set_blendmode(bm_normal);
                var _lscroll = waterfall_scroll * BULB_WATERFALL_SPARKLE_SCROLL;
                for (var _lj = 0; _lj < array_length(waterfall_side_streams); _lj++) {
                    var _ls = waterfall_side_streams[_lj];
                    if (!variable_struct_exists(_ls, "sparkles")) continue;
                    scr_waterfall_draw_sparkles(
                        _ls.x + _ls.width * 0.5,
                        _ls.y0,
                        _ls.y1,
                        _ls.sparkles,
                        _lscroll,
                        _col_mid,
                        _col_bri
                    );
                }
            }

            if (BULB_WATERFALL_LEAK_FOOT_FOAM && array_length(waterfall_side_foam) > 0) {
                gpu_set_blendmode(bm_normal);
                for (var _fi = 0; _fi < array_length(waterfall_side_foam); _fi++) {
                    var _f = waterfall_side_foam[_fi];
                    var _ft = clamp(_f.life / max(1, _f.life_max), 0, 1);
                    draw_set_color(_f.color);
                    draw_set_alpha(0.5 * _ft);
                    draw_circle(_f.x, _f.y, max(1, _f.size), false);
                }
            }
        }

        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
        gpu_set_texfilter(_old_tex);
    }
}

/// @description Clear stream tiles after baking soft columns (keeps layer for depth/draw script).
function scr_waterfall_clear_stream_tiles(_tmap) {
    if (_tmap == -1) return;
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_tmap, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) != BULB_WATERFALL_TILE_STREAM) continue;
            tilemap_set(_tmap, 0, _cx, _cy);
        }
    }
}

/// @description Find underside Y of the platform under a splash (first air below floor).
function scr_waterfall_find_platform_underside(_x, _floor_y) {
    var _tm = (variable_global_exists("tilemap_collision_id") ? global.tilemap_collision_id : noone);
    if (_tm == noone || _tm == -1) return _floor_y + 8;

    var _px = floor(_x);
    var _y = floor(_floor_y);
    var _limit = _y + BULB_WATERFALL_LEAK_PLATFORM_MAX_H;
    while (_y < _limit) {
        if (!scr_ceiling_drip_point_is_floor(_tm, _px, _y)) {
            return _y;
        }
        _y += 1;
    }
    return _floor_y + 8;
}

/// @description End Y for a side stream. Pond / nearby pools snap; long voids run past room bottom.
/// @returns {Struct} { y1, on_floor, hits_pond }
function scr_waterfall_find_stream_end(_x, _start_y) {
    var _pond_y = scr_pond_surface_y_at(_x);
    if (_pond_y != undefined && _pond_y > _start_y + 4 && _pond_y <= _start_y + max(BULB_WATERFALL_LEAK_POOL_SNAP, BULB_WATERFALL_POND_SNAP)) {
        return { y1: _pond_y, on_floor: true, hits_pond: true };
    }

    var _floor = scr_ceiling_drip_find_floor_y(_x, _start_y + 2);
    if (_floor != undefined && _floor > _start_y + 4 && _floor <= _start_y + BULB_WATERFALL_LEAK_POOL_SNAP) {
        return { y1: _floor, on_floor: true, hits_pond: false };
    }

    // Keep falling well past the room so the cut is never visible in-camera.
    var _void_end = max(_start_y + BULB_WATERFALL_LEAK_MAX_FALL, room_height + 96);
    return { y1: _void_end, on_floor: false, hits_pond: false };
}

/// @description Horizontal moving water sheet on the splash platform (feeds into side leaks).
/// Skipped when the main stream lands in a pond (no ledge to pour across).
function scr_waterfall_bake_ground_sheets(_splash_emitters) {
    var _sheets = [];
    if (_splash_emitters == undefined) return _sheets;

    var _h = max(4, BULB_WATERFALL_GROUND_SHEET_H);
    for (var _i = 0; _i < array_length(_splash_emitters); _i++) {
        var _em = _splash_emitters[_i];
        if (variable_struct_exists(_em, "hits_pond") && _em.hits_pond) continue;
        var _w = max(8, _em.right - _em.left);
        var _sparkles = [];
        if (BULB_WATERFALL_SPARKLE_ENABLED) {
            var _n = BULB_WATERFALL_GROUND_SPARKLE_N;
            for (var _s = 0; _s < _n; _s++) {
                var _ox = random(_w);
                // Exact 50/50 split — half drift left, half drift right.
                var _flow = ((_s mod 2) == 0) ? -1 : 1;
                array_push(_sparkles, {
                    ox: _ox,
                    oy: random(_h),
                    kind: (irandom(99) < 60) ? 0 : 1, // 0 = dot, 1 = short horizontal dash
                    len: irandom_range(2, 4),
                    bright: (irandom(99) < 40),
                    flow_dir: _flow
                });
            }
        }

        array_push(_sheets, {
            left: _em.left,
            right: _em.right,
            y: _em.y,
            h: _h,
            sparkles: _sparkles
        });
    }
    return _sheets;
}

/// @description Two thinner side waterfalls joined to each splash (pour off left/right).
/// Platform landings only — main streams that hit a pond stay as a single splash.
function scr_waterfall_bake_side_streams(_splash_emitters) {
    var _streams = [];
    if (_splash_emitters == undefined) return _streams;

    var _w = max(3, BULB_WATERFALL_LEAK_WIDTH);
    var _inset = BULB_WATERFALL_LEAK_INSET;

    for (var _i = 0; _i < array_length(_splash_emitters); _i++) {
        var _em = _splash_emitters[_i];
        if (variable_struct_exists(_em, "hits_pond") && _em.hits_pond) continue;
        var _under = scr_waterfall_find_platform_underside(_em.x, _em.y);

        var _left_x = _em.left + _inset;
        var _right_x = _em.right - _inset - _w;

        var _left = scr_waterfall_find_stream_end(_left_x + _w * 0.5, _under);
        var _right = scr_waterfall_find_stream_end(_right_x + _w * 0.5, _under);
        var _half = max(2, _w * 0.5);

        // Start at platform top so the ground sheet meets the leak; drop flush (no circles).
        var _y0 = _em.y;
        array_push(_streams, {
            x: _left_x,
            y_splash: _em.y,
            y_lip: _under,
            y0: _y0,
            y1: _left.y1,
            width: _w,
            scroll: random(16),
            side: -1,
            pool_x: _em.x,
            on_floor: _left.on_floor,
            sparkles: scr_waterfall_bake_sparkles(_half, max(8, _left.y1 - _y0))
        });
        array_push(_streams, {
            x: _right_x,
            y_splash: _em.y,
            y_lip: _under,
            y0: _y0,
            y1: _right.y1,
            width: _w,
            scroll: random(16),
            side: 1,
            pool_x: _em.x,
            on_floor: _right.on_floor,
            sparkles: scr_waterfall_bake_sparkles(_half, max(8, _right.y1 - _y0))
        });
    }

    return _streams;
}

/// @description One bubble in the foam mound — rounder disk, soft spill into side leaks.
function scr_waterfall_spawn_splash_particle(_em) {
    var _life = irandom_range(BULB_WATERFALL_SPLASH_LIFE_MIN, BULB_WATERFALL_SPLASH_LIFE_MAX);
    var _w = max(8, _em.width);
    var _hits_pond = variable_struct_exists(_em, "hits_pond") && _em.hits_pond;

    // Sample a rounder half-ellipse (wider than tall) so the mound reads circular.
    var _nx;
    var _ny;
    repeat (12) {
        _nx = random_range(-1, 1);
        _ny = random_range(0, 1);
        // Ellipse: x^2 + (y*1.15)^2 <= 1  → flatter, rounder foam mound
        if ((_nx * _nx) + (_ny * _ny * 1.32) <= 1) break;
    }

    // Bias a few toward the outer rim so foam pours smoothly into the leaks (platforms only).
    if (!_hits_pond && BULB_WATERFALL_LEAK_ENABLED && irandom(99) < 40) {
        _nx = (irandom(1) == 0) ? random_range(-1, -0.55) : random_range(0.55, 1);
        _ny = random_range(0, 0.55) * (1 - abs(_nx) * 0.35);
    }

    var _px = _em.x + _nx * _w * 0.46;
    var _py = _em.y - _ny * BULB_WATERFALL_SPLASH_RISE - random(1);

    var _out = sign(_nx);
    if (_out == 0) _out = choose(-1, 1);

    return {
        x: _px,
        y: _py,
        ox: _px,
        base_y: _em.y,
        vx: random_range(-BULB_WATERFALL_SPLASH_JITTER, BULB_WATERFALL_SPLASH_JITTER) + _out * 0.18,
        vy: random_range(-0.15, 0.2),
        life: _life,
        life_max: _life,
        // More even circle sizes — reads as round bubbles, not jagged blobs.
        size: choose(2.5, 3, 3, 3.5, 3.5, 4, 4.5),
        color: scr_waterfall_splash_pick_color(),
        spill: (!_hits_pond && abs(_nx) > 0.5)
    };
}

/// @description Tiny foot-foam bubble at the end of a side stream.
function scr_waterfall_spawn_side_foam(_stream) {
    var _life = irandom_range(10, 22);
    var _cx = _stream.x + _stream.width * 0.5;
    return {
        x: _cx + random_range(-BULB_WATERFALL_LEAK_FOOT_PAD, BULB_WATERFALL_LEAK_FOOT_PAD),
        y: _stream.y1 - random_range(0, 5),
        base_y: _stream.y1,
        vx: random_range(-0.4, 0.4),
        vy: random_range(-0.55, 0.1),
        life: _life,
        life_max: _life,
        size: choose(1.5, 2, 2.5, 3),
        color: scr_waterfall_splash_pick_color()
    };
}

/// @description Soft translucent capsule. Flush flags skip rounded ends (no circle blobs).
function scr_waterfall_draw_soft_stream(_cx, _y0, _y1, _half_w, _col, _alpha, _flush_foot = false, _flush_top = false) {
    if (_y1 <= _y0 || _half_w < 1) return;

    var _bot_r = max(2, _half_w * 0.85);

    draw_set_color(_col);
    draw_set_alpha(_alpha);

    if (!_flush_top) {
        var _top_r = _half_w + 1;
        draw_circle(_cx, _y0, _top_r, false);
        draw_circle(_cx - _half_w * 0.35, _y0 + 1, _top_r * 0.7, false);
        draw_circle(_cx + _half_w * 0.35, _y0 + 1, _top_r * 0.7, false);
    }

    // Soft body: nested narrower fills (fake soft edges, no internal lines).
    var _body_top = _flush_top ? _y0 : (_y0 + 1);
    var _body_bot = _flush_foot ? _y1 : (_y1 - _bot_r);
    if (_body_bot > _body_top) {
        draw_set_alpha(_alpha * 0.9);
        draw_rectangle(_cx - _half_w, _body_top, _cx + _half_w, _body_bot, false);
        if (_half_w >= 3) {
            draw_set_alpha(_alpha * 0.55);
            draw_rectangle(_cx - (_half_w - 1), _body_top, _cx + (_half_w - 1), _body_bot, false);
        }
        if (_half_w >= 5) {
            draw_set_alpha(_alpha * 0.35);
            draw_rectangle(_cx - (_half_w - 2), _body_top, _cx + (_half_w - 2), _body_bot, false);
        }
    }

    if (!_flush_foot) {
        draw_set_alpha(_alpha * 0.75);
        draw_circle(_cx, _y1 - 1, _bot_r, false);
    }
}

/// @description Moving ground sheet on the splash ledge — flows outward into side leaks.
function scr_waterfall_draw_ground_sheet(_sheet, _scroll, _col_base, _col_mid, _col_bri) {
    var _x1 = _sheet.left;
    var _x2 = _sheet.right;
    var _y2 = _sheet.y + 1;
    var _y1 = _sheet.y - _sheet.h;
    var _a = BULB_WATERFALL_GROUND_SHEET_ALPHA;
    var _w = max(1, _x2 - _x1);
    var _mid_y = (_y1 + _y2) * 0.5;
    var _end_r = max(4, _sheet.h * 0.75);

    // Main sheet body (slightly inset so round end-caps define the silhouette).
    draw_set_color(_col_base);
    draw_set_alpha(_a);
    draw_rectangle(_x1 + _end_r * 0.35, _y1, _x2 - _end_r * 0.35, _y2, false);
    draw_set_color(_col_mid);
    draw_set_alpha(_a * 0.7);
    draw_rectangle(_x1 + _end_r * 0.45, _y1 + 1, _x2 - _end_r * 0.45, _y2, false);

    // Round end-caps that pour into the side leaks.
    draw_set_color(_col_base);
    draw_set_alpha(_a);
    draw_circle(_x1 + _end_r * 0.35, _mid_y, _end_r, false);
    draw_circle(_x2 - _end_r * 0.35, _mid_y, _end_r, false);
    draw_set_color(_col_mid);
    draw_set_alpha(_a * 0.75);
    draw_circle(_x1 + _end_r * 0.2, _mid_y + 0.5, _end_r * 0.85, false);
    draw_circle(_x2 - _end_r * 0.2, _mid_y + 0.5, _end_r * 0.85, false);
    draw_set_color(_col_bri);
    draw_set_alpha(_a * 0.4);
    draw_circle(_x1 + 1, _sheet.y - 1, _end_r * 0.65, false);
    draw_circle(_x2 - 1, _sheet.y - 1, _end_r * 0.65, false);

    if (!BULB_WATERFALL_SPARKLE_ENABLED) return;
    if (!variable_struct_exists(_sheet, "sparkles")) return;

    gpu_set_texfilter(false);
    for (var _si = 0; _si < array_length(_sheet.sparkles); _si++) {
        var _sp = _sheet.sparkles[_si];
        var _flow = variable_struct_exists(_sp, "flow_dir") ? _sp.flow_dir : (((_si mod 2) == 0) ? -1 : 1);
        var _px_off;
        if (_flow < 0) {
            _px_off = (_sp.ox - _scroll * 1.4) mod _w;
        } else {
            _px_off = (_sp.ox + _scroll * 1.4) mod _w;
        }
        if (_px_off < 0) _px_off += _w;
        var _px = _x1 + _px_off;
        var _py = floor(_y1 + _sp.oy);

        draw_set_color(_sp.bright ? _col_bri : _col_mid);
        draw_set_alpha(BULB_WATERFALL_SPARKLE_ALPHA * (_sp.bright ? 0.85 : 0.6));

        if (_sp.kind == 0) {
            draw_rectangle(floor(_px), _py, floor(_px), _py, false);
        } else {
            var _len = _sp.len;
            var _x_a = floor(_px);
            var _x_b = _x_a + (_flow * _len);
            draw_rectangle(min(_x_a, _x_b), _py, max(_x_a, _x_b), _py, false);
        }
    }
}

function scr_waterfall_step(_controller) {
    if (!BULB_WATERFALL_ENABLED) return;
    with (_controller) {
        if (!variable_instance_exists(id, "waterfall_scroll")) waterfall_scroll = 0;
        if (!variable_instance_exists(id, "waterfall_baked")) waterfall_baked = false;
        waterfall_scroll += BULB_WATERFALL_SCROLL_SPEED;

        if (!waterfall_baked) return;
        if (!variable_instance_exists(id, "waterfall_splash_emitters")) waterfall_splash_emitters = [];
        if (!variable_instance_exists(id, "waterfall_splash_list")) waterfall_splash_list = [];
        if (!variable_instance_exists(id, "waterfall_side_streams")) waterfall_side_streams = [];
        if (!variable_instance_exists(id, "waterfall_side_foam")) waterfall_side_foam = [];
        if (!variable_instance_exists(id, "waterfall_sfx_id")) waterfall_sfx_id = -1;
        if (!variable_instance_exists(id, "waterfall_sfx_gain")) waterfall_sfx_gain = 0;

        scr_waterfall_sfx_update(id);

        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;
        var _vx = camera_get_view_x(_cam);
        var _vy = camera_get_view_y(_cam);
        var _vw = camera_get_view_width(_cam);
        var _vh = camera_get_view_height(_cam);
        var _pad = BULB_WATERFALL_SPLASH_VIEW_PAD;

        if (BULB_WATERFALL_SPLASH_ENABLED) {
            for (var _e = 0; _e < array_length(waterfall_splash_emitters); _e++) {
                var _em = waterfall_splash_emitters[_e];
                if (_em.right < _vx - _pad || _em.left > _vx + _vw + _pad) continue;
                if (_em.y < _vy - _pad || _em.y > _vy + _vh + _pad) continue;

                var _need = BULB_WATERFALL_SPLASH_PER_EMITTER;
                var _have = 0;
                for (var _c = 0; _c < array_length(waterfall_splash_list); _c++) {
                    if (abs(waterfall_splash_list[_c].ox - _em.x) <= _em.width * 0.55) _have += 1;
                }

                var _spawn = min(_need - _have, BULB_WATERFALL_SPLASH_REFILL);
                repeat (max(0, _spawn)) {
                    if (array_length(waterfall_splash_list) >= BULB_WATERFALL_SPLASH_MAX) break;
                    array_push(waterfall_splash_list, scr_waterfall_spawn_splash_particle(_em));
                }
            }

            for (var _i = array_length(waterfall_splash_list) - 1; _i >= 0; _i--) {
                var _p = waterfall_splash_list[_i];
                _p.x += _p.vx + random_range(-0.25, 0.25);
                _p.y += _p.vy + random_range(-0.2, 0.25);

                // Edge spill bubbles can drip over the lip into the side streams.
                if (variable_struct_exists(_p, "spill") && _p.spill) {
                    if (_p.y > _p.base_y + 2) {
                        // Keep falling a bit past the platform top (joins side streams).
                        _p.vy = min(_p.vy + 0.05, 1.4);
                    } else if (_p.y > _p.base_y - 1) {
                        _p.vy = max(_p.vy, 0.15);
                    }
                } else {
                    if (_p.y > _p.base_y - 1) {
                        _p.y = _p.base_y - 1 - random(2);
                        _p.vy = random_range(-0.4, -0.05);
                    }
                    if (_p.y < _p.base_y - BULB_WATERFALL_SPLASH_HEIGHT - 2) {
                        _p.vy = abs(_p.vy) * 0.5;
                    }
                }

                _p.life -= 1;
                if (_p.life <= 0 || _p.y > _p.base_y + 48) {
                    array_delete(waterfall_splash_list, _i, 1);
                } else {
                    waterfall_splash_list[_i] = _p;
                }
            }
        }

        if (BULB_WATERFALL_LEAK_ENABLED) {
            for (var _s = 0; _s < array_length(waterfall_side_streams); _s++) {
                var _st = waterfall_side_streams[_s];
                _st.scroll = (_st.scroll + BULB_WATERFALL_LEAK_SCROLL_SPEED) mod 16;
                waterfall_side_streams[_s] = _st;

                if (!BULB_WATERFALL_LEAK_FOOT_FOAM) continue;
                // Only foam when the leak lands on a nearby pool — void falls go off-screen with no tip.
                if (!variable_struct_exists(_st, "on_floor") || !_st.on_floor) continue;
                if (_st.x + _st.width < _vx - _pad || _st.x > _vx + _vw + _pad) continue;
                if (_st.y1 < _vy - _pad || _st.y0 > _vy + _vh + _pad) continue;

                if (array_length(waterfall_side_foam) < BULB_WATERFALL_LEAK_FOOT_BUBBLES * max(1, array_length(waterfall_side_streams))) {
                    if (irandom(2) == 0) {
                        array_push(waterfall_side_foam, scr_waterfall_spawn_side_foam(_st));
                    }
                }
            }

            for (var _fi = array_length(waterfall_side_foam) - 1; _fi >= 0; _fi--) {
                var _f = waterfall_side_foam[_fi];
                _f.x += _f.vx;
                _f.y += _f.vy;
                _f.vy += 0.08;
                if (_f.y > _f.base_y) {
                    _f.y = _f.base_y - random(2);
                    _f.vy = random_range(-0.45, -0.05);
                }
                _f.life -= 1;
                if (_f.life <= 0) {
                    array_delete(waterfall_side_foam, _fi, 1);
                } else {
                    waterfall_side_foam[_fi] = _f;
                }
            }
        }
    }
}

/// @description World-locked X + wrapped Y scroll — stays where you placed it in the room.
function scr_waterfall_parallax_apply(_ctrl) {
    if (!BULB_WATERFALL_ENABLED) return;
    if (!instance_exists(obj_bulb_controller)) return;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "waterfall_baked") || !waterfall_baked) return;
        if (!variable_instance_exists(id, "waterfall_layer_id") || waterfall_layer_id == -1) return;

        layer_x(waterfall_layer_id, waterfall_start_x);

        var _th = max(1, waterfall_tile_h);
        var _off = waterfall_scroll mod _th;
        if (_off < 0) _off += _th;
        layer_y(waterfall_layer_id, waterfall_start_y + _off);
    }
}

/// @description Post-Draw noop — waterfall FX draw on Tiles_Waterfall (behind player).
function scr_waterfall_draw(_controller) {
    // Intentionally empty. Splash / leaks / soft stream are drawn in
    // scr_waterfall_layer_draw_soft so the player stays visually in front.
}

/// @description Nearest splash / stream point for distance-based waterfall ambience.
function scr_waterfall_sfx_nearest_point(_controller) {
    with (_controller) {
        var _best = undefined;
        var _best_d = 1000000000;
        var _px = instance_exists(obj_player) ? obj_player.x : 0;
        var _py = instance_exists(obj_player) ? obj_player.y : 0;

        if (variable_instance_exists(id, "waterfall_splash_emitters")) {
            for (var _i = 0; _i < array_length(waterfall_splash_emitters); _i++) {
                var _em = waterfall_splash_emitters[_i];
                var _d = instance_exists(obj_player) ? point_distance(_em.x, _em.y, _px, _py) : 0;
                if (_d < _best_d) {
                    _best_d = _d;
                    _best = { x: _em.x, y: _em.y, dist: _d };
                }
            }
        }

        if (_best == undefined && variable_instance_exists(id, "waterfall_soft_columns")) {
            for (var _c = 0; _c < array_length(waterfall_soft_columns); _c++) {
                var _col = waterfall_soft_columns[_c];
                var _cy = (_col.y0 + _col.y1) * 0.5;
                var _d2 = instance_exists(obj_player) ? point_distance(_col.cx, _cy, _px, _py) : 0;
                if (_d2 < _best_d) {
                    _best_d = _d2;
                    _best = { x: _col.cx, y: _cy, dist: _d2 };
                }
            }
        }

        return _best;
    }
    return undefined;
}

/// @description Ensure waterfall SFX bus/emitter exist (safe if global_init ran before this existed).
function scr_waterfall_sfx_ensure_bus() {
    if (variable_global_exists("sfx_waterfall_emitter")) return true;

    global.sfx_waterfall_emitter = audio_emitter_create();
    audio_emitter_falloff(global.sfx_waterfall_emitter, 100, 1000000, 0);
    audio_emitter_gain(global.sfx_waterfall_emitter, 1);

    global.sfx_waterfall_bus = audio_bus_create();
    audio_emitter_bus(global.sfx_waterfall_emitter, global.sfx_waterfall_bus);

    var _wf_reverb = audio_effect_create(AudioEffectType.Reverb1);
    _wf_reverb.size = BULB_WATERFALL_SFX_REVERB_SIZE;
    _wf_reverb.damp = BULB_WATERFALL_SFX_REVERB_DAMP;
    _wf_reverb.mix  = BULB_WATERFALL_SFX_REVERB_MIX;
    global.sfx_waterfall_bus.effects[0] = _wf_reverb;

    var _wf_echo = audio_effect_create(AudioEffectType.Delay);
    _wf_echo.time = BULB_WATERFALL_SFX_ECHO_TIME;
    _wf_echo.feedback = BULB_WATERFALL_SFX_ECHO_FEEDBACK;
    _wf_echo.mix = BULB_WATERFALL_SFX_ECHO_MIX;
    global.sfx_waterfall_bus.effects[1] = _wf_echo;

    return true;
}

/// @description Start looping waterfall ambience (cave reverb + slap echo bus).
function scr_waterfall_sfx_start(_controller) {
    if (!BULB_WATERFALL_ENABLED || !BULB_WATERFALL_SFX_ENABLED) return;
    scr_waterfall_sfx_ensure_bus();

    with (_controller) {
        if (!variable_instance_exists(id, "waterfall_sfx_id")) waterfall_sfx_id = -1;
        if (!variable_instance_exists(id, "waterfall_sfx_gain")) waterfall_sfx_gain = 0;

        var _pt = scr_waterfall_sfx_nearest_point(id);
        if (_pt == undefined) return;

        if (waterfall_sfx_id != -1 && audio_is_playing(waterfall_sfx_id)) return;

        scr_waterfall_sfx_stop(id);

        var _emitter = global.sfx_waterfall_emitter;
        waterfall_sfx_id = audio_play_sound_on(
            _emitter,
            snd_waterfall,
            true,
            BULB_WATERFALL_SFX_AUDIO_PRIORITY,
            BULB_WATERFALL_SFX_VOL_MIN,
            0,
            BULB_WATERFALL_SFX_PITCH
        );

        // Fallback: plain play if emitter path failed.
        if (waterfall_sfx_id == -1) {
            waterfall_sfx_id = audio_play_sound(snd_waterfall, BULB_WATERFALL_SFX_AUDIO_PRIORITY, true);
            if (waterfall_sfx_id != -1) {
                audio_sound_gain(waterfall_sfx_id, BULB_WATERFALL_SFX_VOL_MIN, 0);
                audio_sound_pitch(waterfall_sfx_id, BULB_WATERFALL_SFX_PITCH);
            }
        }

        waterfall_sfx_gain = BULB_WATERFALL_SFX_VOL_MIN;
    }
}

/// @description Stop waterfall ambience loop.
function scr_waterfall_sfx_stop(_controller) {
    with (_controller) {
        if (!variable_instance_exists(id, "waterfall_sfx_id")) waterfall_sfx_id = -1;
        if (waterfall_sfx_id != -1) {
            if (audio_is_playing(waterfall_sfx_id)) {
                audio_stop_sound(waterfall_sfx_id);
            }
            waterfall_sfx_id = -1;
        }
        waterfall_sfx_gain = 0;
    }
}

/// @description Fade waterfall loop gain by distance / view (same idea as drip splash SFX).
function scr_waterfall_sfx_update(_controller) {
    if (!BULB_WATERFALL_ENABLED || !BULB_WATERFALL_SFX_ENABLED) {
        scr_waterfall_sfx_stop(_controller);
        return;
    }

    with (_controller) {
        if (!variable_instance_exists(id, "waterfall_baked") || !waterfall_baked) return;
        if (!variable_instance_exists(id, "waterfall_sfx_id")) waterfall_sfx_id = -1;
        if (!variable_instance_exists(id, "waterfall_sfx_gain")) waterfall_sfx_gain = 0;

        var _pt = scr_waterfall_sfx_nearest_point(id);
        if (_pt == undefined) {
            scr_waterfall_sfx_stop(id);
            return;
        }

        if (waterfall_sfx_id == -1 || !audio_is_playing(waterfall_sfx_id)) {
            scr_waterfall_sfx_start(id);
            if (waterfall_sfx_id == -1) return;
        }

        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;
        var _vx = camera_get_view_x(_cam);
        var _vy = camera_get_view_y(_cam);
        var _vw = camera_get_view_width(_cam);
        var _vh = camera_get_view_height(_cam);
        var _pad = BULB_WATERFALL_SFX_VIEW_PAD;

        var _in_view = !(_pt.x < _vx - _pad || _pt.x > _vx + _vw + _pad
            || _pt.y < _vy - _pad || _pt.y > _vy + _vh + _pad);

        var _target = 0;
        if (instance_exists(obj_player)) {
            var _dist = _pt.dist;
            var _hear = BULB_WATERFALL_SFX_HEAR_RADIUS;
            if (_dist <= _hear) {
                var _t = clamp(1 - (_dist / max(1, _hear)), 0, 1);
                _target = lerp(BULB_WATERFALL_SFX_VOL_MIN, BULB_WATERFALL_SFX_VOL_MAX, _t);
                if (!_in_view) _target *= 0.55;
            } else if (_in_view) {
                // Visible but outside hear radius — keep a quiet bed so it isn't totally silent on-screen.
                _target = BULB_WATERFALL_SFX_VOL_MIN * 0.65;
            }
        } else if (_in_view) {
            _target = BULB_WATERFALL_SFX_VOL_MIN;
        }

        if (abs(_target - waterfall_sfx_gain) > 0.005) {
            waterfall_sfx_gain = _target;
            audio_sound_gain(waterfall_sfx_id, _target, BULB_WATERFALL_SFX_FADE_MS);
        }
    }
}

function scr_waterfall_restore_front_layers(_lit_surface) {
}

function scr_waterfall_cache_free(_controller) {
    scr_waterfall_sfx_stop(_controller);
}
