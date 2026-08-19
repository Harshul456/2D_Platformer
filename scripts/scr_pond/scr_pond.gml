/// @description Flooded-chamber ponds from tile-23 markers on Tiles_Pond.
/// Paint filled regions of tile 23; bake clears tiles and draws a rectangular
/// water body (rippled surface, depth gradient, bubbles).

/// @description Init pond state on obj_bulb_controller.
function scr_pond_init(_controller) {
    with (_controller) {
        pond_layer_id = -1;
        pond_tilemap = -1;
        pond_baked = false;
        pond_scroll = 0;
        pond_surface_scroll = 0;
        pond_player_wet = false;
        pond_list = [];
        pond_perf_us = 0;
        pond_perf_calls = 0;
        pond_perf_us_acc = 0;
        pond_perf_calls_acc = 0;
    }
}

function scr_pond_extract_from_tilemap(_src, _dst) {
    if (_src == -1 || _dst == -1) return 0;

    var _w = min(tilemap_get_width(_src), tilemap_get_width(_dst));
    var _h = min(tilemap_get_height(_src), tilemap_get_height(_dst));
    var _count = 0;

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_src, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) != BULB_POND_TILE) continue;
            tilemap_set(_dst, _td, _cx, _cy);
            tilemap_set(_src, 0, _cx, _cy);
            _count += 1;
        }
    }

    return _count;
}

function scr_pond_tilemap_has_pond(_tmap) {
    if (_tmap == -1) return false;
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_tmap, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) == BULB_POND_TILE) return true;
        }
    }
    return false;
}

function scr_pond_clear_tiles(_tmap) {
    if (_tmap == -1) return;
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _td = tilemap_get(_tmap, _cx, _cy);
            if (tile_get_empty(_td)) continue;
            if (tile_get_index(_td) != BULB_POND_TILE) continue;
            tilemap_set(_tmap, 0, _cx, _cy);
        }
    }
}

/// @description Bubbles / sparkles drifting inside the water volume.
function scr_pond_bake_sparkles(_w, _h) {
    var _sparkles = [];
    if (!BULB_POND_SPARKLE_ENABLED) return _sparkles;

    var _n = clamp(floor(_w * _h * BULB_POND_SPARKLE_DENSITY), 6, BULB_POND_SPARKLE_MAX);
    for (var _s = 0; _s < _n; _s++) {
        array_push(_sparkles, {
            ox: random(_w),
            oy: random(_h),
            kind: (irandom(99) < 70) ? 0 : 1,
            len: irandom_range(2, 4),
            bright: (irandom(99) < 30),
            flow_dir: ((_s mod 2) == 0) ? -1 : 1
        });
    }
    return _sparkles;
}

/// @description Baked ripple offsets for a jagged cyan surface line.
function scr_pond_bake_surface(_w) {
    var _amps = [];
    var _amp = BULB_POND_SURFACE_AMP;
    var _prev = 0;
    var _len = max(16, ceil(_w) + 48);
    for (var _x = 0; _x < _len; _x++) {
        var _next = _prev;
        if ((_x mod 2) == 0) {
            _next = irandom_range(-_amp, _amp);
            if (abs(_next - _prev) > 1) _next = _prev + sign(_next - _prev);
        }
        array_push(_amps, _next);
        _prev = _next;
    }
    return _amps;
}

/// @description Foam / spray dots that ride the animated surface crest.
function scr_pond_bake_surface_dots(_w) {
    var _dots = [];
    if (!BULB_POND_SURFACE_DOT_ENABLED) return _dots;

    var _n = clamp(floor(_w * BULB_POND_SURFACE_DOT_DENSITY), 4, BULB_POND_SURFACE_DOT_MAX);
    for (var _i = 0; _i < _n; _i++) {
        array_push(_dots, {
            ox: random(_w),
            bias: irandom_range(-1, 2),
            bright: (irandom(99) < 55),
            phase: random(6.28),
            speed: random_range(0.7, 1.3)
        });
    }
    return _dots;
}

/// @description Spring-chain nodes along the waterline. Height is a pixel offset from
/// rest (positive = pushed down); velocity carries the disturbance along the surface.
function scr_pond_bake_waves(_w) {
    var _n = max(2, ceil(_w / BULB_POND_WAVE_STEP) + 1);
    return {
        h: array_create(_n, 0),
        v: array_create(_n, 0)
    };
}

/// @description Largest distance the waterline can sit from rest, in pixels. The body
/// bands start this far down so the wavy top edge is drawn per column instead.
function scr_pond_surface_pad() {
    var _pad = BULB_POND_SURFACE_AMP + BULB_POND_SURFACE_WAVE + 1;
    if (BULB_POND_WAVE_ENABLED) _pad += BULB_POND_WAVE_MAX_PX;
    return _pad;
}

/// @description Advance one pond's surface springs: propagate to neighbours, pull back
/// to rest, damp. Velocities are all computed from the current heights before any
/// height is written, so the pass stays symmetric.
function scr_pond_wave_step(_pond) {
    if (!BULB_POND_WAVE_ENABLED) return;
    if (!variable_struct_exists(_pond, "wave")) return;
    // An undisturbed pool is the common case, so once it settles we zero it out and stop
    // simulating and sampling until scr_pond_disturb wakes it again.
    if (_pond.wave_idle) return;

    var _h = _pond.wave.h;
    var _v = _pond.wave.v;
    var _n = array_length(_h);
    if (_n < 2) return;

    var _k = BULB_POND_WAVE_STIFFNESS;
    var _spread = BULB_POND_WAVE_SPREAD;
    var _damp = BULB_POND_WAVE_DAMPING;
    var _max = BULB_POND_WAVE_MAX_PX;

    for (var _i = 0; _i < _n; _i++) {
        var _hi = _h[_i];
        var _neighbour = (_h[max(0, _i - 1)] + _h[min(_n - 1, _i + 1)]) * 0.5;
        var _vel = _v[_i] + (_neighbour - _hi) * _spread - _hi * _k;
        _v[_i] = _vel * _damp;
    }

    var _peak = 0;
    for (var _j = 0; _j < _n; _j++) {
        var _hj = clamp(_h[_j] + _v[_j], -_max, _max);
        _h[_j] = _hj;
        _peak = max(_peak, abs(_hj), abs(_v[_j]));
    }

    if (_peak < 0.05) {
        for (var _z = 0; _z < _n; _z++) {
            _h[_z] = 0;
            _v[_z] = 0;
        }
        _pond.wave_idle = true;
    }
}

/// @description Interpolated wave height at a local X along the pond.
function scr_pond_wave_at(_pond, _local_x) {
    if (!BULB_POND_WAVE_ENABLED) return 0;
    if (!variable_struct_exists(_pond, "wave")) return 0;
    if (_pond.wave_idle) return 0;

    var _h = _pond.wave.h;
    var _n = array_length(_h);
    if (_n <= 0) return 0;

    var _c = _local_x / BULB_POND_WAVE_STEP;
    var _i0 = clamp(floor(_c), 0, _n - 1);
    var _i1 = clamp(_i0 + 1, 0, _n - 1);
    return lerp(_h[_i0], _h[_i1], clamp(_c - _i0, 0, 1));
}

/// @description Kick the surface at a world X. Positive impulse pushes the water down.
/// @param {Real} _x        World X of the impact
/// @param {Real} _impulse  Velocity added at the centre, in pixels/frame
/// @param {Real} _radius   Falloff radius in pixels
function scr_pond_disturb(_x, _impulse, _radius) {
    if (!BULB_POND_WAVE_ENABLED || _impulse == 0) return;
    if (!instance_exists(obj_bulb_controller)) return;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "pond_baked") || !pond_baked) return;
        if (!variable_instance_exists(id, "pond_list")) return;

        for (var _i = 0; _i < array_length(pond_list); _i++) {
            var _p = pond_list[_i];
            if (!variable_struct_exists(_p, "wave")) continue;

            var _b = scr_pond_draw_bounds(_p);
            if (_x < _b.left - _radius || _x > _b.right + _radius) continue;

            var _v = _p.wave.v;
            var _n = array_length(_v);
            var _c = (_x - _b.left) / BULB_POND_WAVE_STEP;
            var _span = max(1, _radius / BULB_POND_WAVE_STEP);

            var _k0 = max(0, floor(_c - _span));
            var _k1 = min(_n - 1, ceil(_c + _span));
            for (var _k = _k0; _k <= _k1; _k++) {
                var _t = 1 - (abs(_k - _c) / _span);
                if (_t <= 0) continue;
                _v[_k] += _impulse * _t * _t;
                _p.wave_idle = false;
            }
        }
    }
}

/// @description Animated surface Y offset (pixels) at local X along a pond.
function scr_pond_surface_offset_at(_pond, _local_x, _scroll) {
    if (!variable_struct_exists(_pond, "surface")) return 0;
    var _surf = _pond.surface;
    var _sw = array_length(_surf);
    if (_sw <= 0) return 0;

    var _idx = floor(_local_x + _scroll);
    while (_idx < 0) _idx += _sw;
    _idx = _idx mod _sw;
    var _amp = _surf[_idx];
    var _wave = round(sin((_local_x * 0.18) + (_scroll * 0.35)) * BULB_POND_SURFACE_WAVE);
    return _amp + _wave + scr_pond_wave_at(_pond, _local_x);
}

/// @description Collision tilemap used to snap pond edges under wall art.
function scr_pond_get_collision_tilemap() {
    var _col_layer = layer_get_id("lay_collision");
    if (_col_layer != -1) {
        var _tm = layer_tilemap_get_id(_col_layer);
        if (_tm != -1 && _tm != noone) return _tm;
    }
    if (variable_global_exists("tilemap_collision_id")
        && global.tilemap_collision_id != noone
        && global.tilemap_collision_id != -1) {
        return global.tilemap_collision_id;
    }
    return -1;
}

/// @description Any non-empty tile at this pixel (tile index 0 counts as solid).
function scr_pond_pixel_has_tile(_tmap, _x, _y) {
    if (_tmap == -1 || _tmap == noone) return false;
    var _td = tilemap_get_at_pixel(_tmap, floor(_x), floor(_y));
    return !tile_get_empty(_td);
}

/// @description Tilemaps that can hide a pond overlap: visible, in front of the pond, and
/// world-locked. Parallaxing layers are excluded because tilemap_get_at_pixel ignores the
/// layer's scroll offset, so their tiles are never where we would probe for them.
function scr_pond_get_mask_tilemaps() {
    var _pond_l = layer_get_id(BULB_POND_LAYER);
    if (_pond_l == -1) return [];
    var _pond_depth = layer_get_depth(_pond_l);

    var _names = ["lay_collision", "near_tiles", "foreground"];
    var _out = [];

    for (var _i = 0; _i < array_length(_names); _i++) {
        var _l = layer_get_id(_names[_i]);
        if (_l == -1) continue;
        if (!layer_get_visible(_l)) continue;
        if (layer_get_depth(_l) >= _pond_depth) continue;
        if (layer_get_x(_l) != 0 || layer_get_y(_l) != 0) continue;

        var _tm = layer_tilemap_get_id(_l);
        if (_tm != -1 && _tm != noone) array_push(_out, _tm);
    }

    return _out;
}

/// @description Grow a pond edge into an adjacent wall tile whose art leaves a gap.
/// Only bleeds when a masking wall is actually found — otherwise the edge stays on the
/// tile boundary, so open water never spills past the tiles the pond was painted on.
function scr_pond_snap_edge_to_wall(_edge, _y0, _y1, _dir) {
    var _bleed = BULB_POND_WALL_BLEED;
    if (_bleed <= 0) return _edge;

    var _max_d = BULB_POND_WALL_SNAP_MAX;
    var _maps = scr_pond_get_mask_tilemaps();
    var _map_n = array_length(_maps);
    if (_map_n == 0) return _edge;

    var _samples = [
        lerp(_y0, _y1, 0.15),
        lerp(_y0, _y1, 0.4),
        lerp(_y0, _y1, 0.65),
        lerp(_y0, _y1, 0.9)
    ];

    for (var _d = 1; _d <= _max_d; _d++) {
        var _x = _edge + _dir * _d;
        for (var _s = 0; _s < 4; _s++) {
            var _sy = _samples[_s];
            for (var _m = 0; _m < _map_n; _m++) {
                if (scr_pond_pixel_has_tile(_maps[_m], _x, _sy)) {
                    return _x + _dir * _bleed;
                }
            }
        }
    }

    return _edge;
}

/// @description Draw bounds for a pond, reusing a struct cached on the pond itself.
/// This is hit by the draw loop and by every ceiling drip / waterfall probe each frame,
/// so returning a fresh struct here was steady allocation churn. With no wall bleed the
/// edges are exactly the tile bounds, so the wall scan is skipped outright.
function scr_pond_draw_bounds(_p) {
    if (!variable_struct_exists(_p, "bounds")) {
        _p.bounds = {
            left: _p.left,
            right: _p.right,
            top: _p.top,
            bottom: _p.bottom,
            w: _p.right - _p.left,
            h: _p.bottom - _p.top
        };
    }
    var _b = _p.bounds;
    if (BULB_POND_WALL_BLEED > 0) {
        _b.left = scr_pond_snap_edge_to_wall(_p.tile_left, _p.top, _p.bottom, -1);
        _b.right = scr_pond_snap_edge_to_wall(_p.tile_right, _p.top, _p.bottom, 1);
        _b.w = _b.right - _b.left;
    }
    return _b;
}

/// @description Flood-fill connected tile-23 cells into rectangular pond volumes.
function scr_pond_bake_regions(_tmap, _layer) {
    var _ponds = [];
    if (_tmap == -1) return _ponds;

    var _tw = tilemap_get_tile_width(_tmap);
    var _th = tilemap_get_tile_height(_tmap);
    var _w = tilemap_get_width(_tmap);
    var _h = tilemap_get_height(_tmap);
    var _ox = layer_get_x(_layer) + tilemap_get_x(_tmap);
    var _oy = layer_get_y(_layer) + tilemap_get_y(_tmap);

    var _visited = array_create(_w * _h, false);

    for (var _sy = 0; _sy < _h; _sy++) {
        for (var _sx = 0; _sx < _w; _sx++) {
            var _si = _sx + _sy * _w;
            if (_visited[_si]) continue;

            var _td0 = tilemap_get(_tmap, _sx, _sy);
            if (tile_get_empty(_td0) || tile_get_index(_td0) != BULB_POND_TILE) {
                _visited[_si] = true;
                continue;
            }

            var _qx = [_sx];
            var _qy = [_sy];
            var _qi = 0;
            _visited[_si] = true;

            var _min_x = _sx;
            var _max_x = _sx;
            var _min_y = _sy;
            var _max_y = _sy;

            while (_qi < array_length(_qx)) {
                var _cx = _qx[_qi];
                var _cy = _qy[_qi];
                _qi += 1;

                if (_cx < _min_x) _min_x = _cx;
                if (_cx > _max_x) _max_x = _cx;
                if (_cy < _min_y) _min_y = _cy;
                if (_cy > _max_y) _max_y = _cy;

                var _nbs = [
                    [_cx - 1, _cy], [_cx + 1, _cy],
                    [_cx, _cy - 1], [_cx, _cy + 1]
                ];
                for (var _n = 0; _n < 4; _n++) {
                    var _nx = _nbs[_n][0];
                    var _ny = _nbs[_n][1];
                    if (_nx < 0 || _ny < 0 || _nx >= _w || _ny >= _h) continue;
                    var _ni = _nx + _ny * _w;
                    if (_visited[_ni]) continue;
                    _visited[_ni] = true;
                    var _td = tilemap_get(_tmap, _nx, _ny);
                    if (tile_get_empty(_td)) continue;
                    if (tile_get_index(_td) != BULB_POND_TILE) continue;
                    array_push(_qx, _nx);
                    array_push(_qy, _ny);
                }
            }

            var _left = _ox + _min_x * _tw;
            var _top = _oy + _min_y * _th;
            var _right = _ox + (_max_x + 1) * _tw;
            var _bottom = _oy + (_max_y + 1) * _th;
            var _pw = _right - _left;
            var _ph = _bottom - _top;
            var _surf_w = _pw + BULB_POND_WALL_SNAP_MAX * 2;

            array_push(_ponds, {
                left: _left,
                top: _top,
                right: _right,
                bottom: _bottom,
                tile_left: _left,
                tile_right: _right,
                cx: (_left + _right) * 0.5,
                cy: (_top + _bottom) * 0.5,
                w: _pw,
                h: _ph,
                bounds: {
                    left: _left,
                    right: _right,
                    top: _top,
                    bottom: _bottom,
                    w: _pw,
                    h: _ph
                },
                surface: scr_pond_bake_surface(_surf_w),
                surface_dots: scr_pond_bake_surface_dots(_surf_w),
                sparkles: scr_pond_bake_sparkles(_pw, _ph),
                wave: scr_pond_bake_waves(_pw),
                wave_idle: true
            });
        }
    }

    return _ponds;
}

/// @description Pond surface Y under world X, or undefined if none.
function scr_pond_surface_y_at(_x) {
    if (!BULB_POND_ENABLED) return undefined;
    if (!instance_exists(obj_bulb_controller)) return undefined;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "pond_baked") || !pond_baked) return undefined;
        if (!variable_instance_exists(id, "pond_list")) return undefined;

        var _best = undefined;
        for (var _i = 0; _i < array_length(pond_list); _i++) {
            var _p = pond_list[_i];
            var _b = scr_pond_draw_bounds(_p);
            if (_x < _b.left || _x > _b.right) continue;
            if (_best == undefined || _p.top < _best) _best = _p.top;
        }
        return _best;
    }
    return undefined;
}

/// @description True if world point sits inside a baked pond volume (at/below surface).
function scr_pond_contains_point(_x, _y) {
    if (!BULB_POND_ENABLED) return false;
    if (!instance_exists(obj_bulb_controller)) return false;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "pond_baked") || !pond_baked) return false;
        if (!variable_instance_exists(id, "pond_list")) return false;

        for (var _i = 0; _i < array_length(pond_list); _i++) {
            var _p = pond_list[_i];
            var _b = scr_pond_draw_bounds(_p);
            if (_x < _b.left || _x > _b.right) continue;
            if (_y < _b.top || _y > _b.bottom) continue;
            return true;
        }
    }
    return false;
}

/// @description Bind Tiles_Pond, pull mid copies of tile 23, bake flooded ponds.
function scr_pond_bake(_controller, _layer_name = BULB_POND_LAYER) {
    if (!BULB_POND_ENABLED) return;

    with (_controller) {
        pond_layer_id = layer_get_id(_layer_name);
        pond_tilemap = -1;
        pond_baked = false;
        pond_scroll = 0;
        pond_surface_scroll = 0;
        pond_player_wet = false;
        pond_list = [];
        if (pond_layer_id == -1) return;

        layer_script_begin(pond_layer_id, scr_pond_layer_script_noop);
        layer_script_end(pond_layer_id, scr_pond_layer_draw);

        pond_tilemap = layer_tilemap_get_id(pond_layer_id);
        if (pond_tilemap == -1) return;

        var _mid = layer_get_id("mid_tiles");
        if (_mid != -1) {
            var _mid_tmap = layer_tilemap_get_id(_mid);
            if (_mid_tmap != -1) {
                scr_pond_extract_from_tilemap(_mid_tmap, pond_tilemap);
            }
        }

        if (!scr_pond_tilemap_has_pond(pond_tilemap)) return;

        // Keep the room's authored depth: in front of mid background rock, but behind
        // near_tiles / lay_collision so those wall tiles mask the seam overlap.
        var _actors = layer_get_id("Instances");
        if (_actors != -1) {
            var _behind_player = layer_get_depth(_actors) + 80;
            if (layer_get_depth(pond_layer_id) < _behind_player) {
                layer_depth(pond_layer_id, _behind_player);
            }
        }

        pond_list = scr_pond_bake_regions(pond_tilemap, pond_layer_id);
        scr_pond_clear_tiles(pond_tilemap);
        layer_set_visible(pond_layer_id, true);
        pond_baked = true;
    }
}

function scr_pond_layer_script_noop() {
}

/// @description 0..1 alpha multiplier that falls off near the pond's left/right ends.
/// @param {Real} _left   Pond left edge (inclusive)
/// @param {Real} _right  Pond right edge (exclusive)
/// @param {Real} _x      Pixel being drawn
function scr_pond_edge_fade_at(_left, _right, _x) {
    var _fade = BULB_POND_EDGE_FADE;
    if (_fade <= 0) return 1;

    var _half = floor((_right - _left) / 2);
    if (_half <= 0) return 1;
    var _f = min(_fade, _half);

    var _d = min(_x - _left, (_right - 1) - _x);
    if (_d < 0) return 0;
    if (_d >= _f) return 1;
    return (_d + 1) / (_f + 1);
}

/// @description Append one axis-aligned quad (two triangles) to an open pr_trianglelist.
/// Lets all the pond's dots / sparkles go out in a single draw call even though each has
/// its own colour and alpha. Right and bottom are exclusive.
function scr_pond_push_quad(_x0, _y0, _x1, _y1, _col, _alpha) {
    draw_vertex_colour(_x0, _y0, _col, _alpha);
    draw_vertex_colour(_x1, _y0, _col, _alpha);
    draw_vertex_colour(_x0, _y1, _col, _alpha);
    draw_vertex_colour(_x1, _y0, _col, _alpha);
    draw_vertex_colour(_x1, _y1, _col, _alpha);
    draw_vertex_colour(_x0, _y1, _col, _alpha);
}

/// @description Filled rect whose left/right ends fade out over BULB_POND_EDGE_FADE pixels.
/// One triangle strip using vertex alpha for the falloff: at the game's internal
/// resolution the ramp still lands on whole pixels, and it costs a single draw call
/// instead of one per pixel column. Coordinates are inclusive on all sides.
function scr_pond_draw_faded_rect(_x0, _y0, _x1, _y1, _col, _alpha) {
    var _w = _x1 - _x0 + 1;
    var _f = min(BULB_POND_EDGE_FADE, floor(_w / 2));

    if (_f <= 0) {
        draw_set_color(_col);
        draw_set_alpha(_alpha);
        draw_rectangle(_x0, _y0, _x1, _y1, false);
        return;
    }

    var _yt = _y0;
    var _yb = _y1 + 1;

    draw_primitive_begin(pr_trianglestrip);
    draw_vertex_colour(_x0, _yt, _col, 0);
    draw_vertex_colour(_x0, _yb, _col, 0);
    draw_vertex_colour(_x0 + _f, _yt, _col, _alpha);
    draw_vertex_colour(_x0 + _f, _yb, _col, _alpha);
    draw_vertex_colour(_x1 + 1 - _f, _yt, _col, _alpha);
    draw_vertex_colour(_x1 + 1 - _f, _yb, _col, _alpha);
    draw_vertex_colour(_x1 + 1, _yt, _col, 0);
    draw_vertex_colour(_x1 + 1, _yb, _col, 0);
    draw_primitive_end();
}

/// @description Player wake and entry splash. Runs from the pond step so obj_player
/// needs no knowledge of the water.
function scr_pond_player_waves(_controller) {
    if (!BULB_POND_WAVE_ENABLED) return;
    if (!instance_exists(obj_player)) return;

    with (_controller) {
        if (!variable_instance_exists(id, "pond_player_wet")) pond_player_wet = false;

        var _px = floor(obj_player.x);
        var _surface = scr_pond_surface_y_at(_px);
        var _wet = (_surface != undefined) && (obj_player.bbox_bottom >= _surface);

        if (_wet && !pond_player_wet) {
            // Entry splash scales with impact speed.
            var _imp = min(BULB_POND_WAVE_LAND_MAX, abs(obj_player.vsp) * BULB_POND_WAVE_LAND_SCALE);
            scr_pond_disturb(_px, max(1.2, _imp), BULB_POND_WAVE_LAND_RADIUS);
        } else if (!_wet && pond_player_wet) {
            // Leaving pulls the surface up behind the player.
            scr_pond_disturb(_px, -abs(obj_player.vsp) * BULB_POND_WAVE_EXIT_SCALE,
                BULB_POND_WAVE_WADE_RADIUS);
        } else if (_wet) {
            var _hs = abs(obj_player.hsp);
            if (_hs > 0.4) {
                // Wake: trough behind the player, crest pushed out ahead.
                var _dir = sign(obj_player.hsp);
                var _amt = _hs * BULB_POND_WAVE_WADE_SCALE;
                scr_pond_disturb(_px - _dir * 4, _amt, BULB_POND_WAVE_WADE_RADIUS);
                scr_pond_disturb(_px + _dir * 6, -_amt * 0.6, BULB_POND_WAVE_WADE_RADIUS);
            }
        }

        pond_player_wet = _wet;
    }
}

function scr_pond_step(_controller) {
    if (!BULB_POND_ENABLED) return;
    with (_controller) {
        if (!variable_instance_exists(id, "pond_scroll")) pond_scroll = 0;
        if (!variable_instance_exists(id, "pond_surface_scroll")) pond_surface_scroll = 0;
        if (!variable_instance_exists(id, "pond_baked")) pond_baked = false;
        pond_scroll += BULB_POND_SPARKLE_SCROLL;
        pond_surface_scroll += BULB_POND_SURFACE_SCROLL;

        if (BULB_POND_DEBUG_PERF) {
            // Step runs once per frame, so this closes off the previous frame's tally.
            pond_perf_us = pond_perf_us_acc;
            pond_perf_calls = pond_perf_calls_acc;
            pond_perf_us_acc = 0;
            pond_perf_calls_acc = 0;
        }

        if (pond_baked && variable_instance_exists(id, "pond_list")) {
            for (var _i = 0; _i < array_length(pond_list); _i++) {
                scr_pond_wave_step(pond_list[_i]);
            }
        }
    }

    scr_pond_player_waves(_controller);
}

/// @description Flooded chamber: depth body, animated surface + foam dots.
function scr_pond_layer_draw() {
    if (!BULB_POND_ENABLED) return;
    if (!instance_exists(obj_bulb_controller)) return;

    var _perf_t0 = BULB_POND_DEBUG_PERF ? get_timer() : 0;

    with (obj_bulb_controller) {
        if (!variable_instance_exists(id, "pond_baked") || !pond_baked) return;
        if (!variable_instance_exists(id, "pond_list")) pond_list = [];
        if (!variable_instance_exists(id, "pond_scroll")) pond_scroll = 0;
        if (!variable_instance_exists(id, "pond_surface_scroll")) pond_surface_scroll = 0;

        var _old_tex = gpu_get_texfilter();
        var _old_blend = gpu_get_blendmode();
        var _old_alpha = draw_get_alpha();
        var _old_col = draw_get_color();

        gpu_set_texfilter(false);
        gpu_set_blendmode(bm_normal);

        var _col_mid = make_colour_rgb(BULB_WATERFALL_COL_MID_R, BULB_WATERFALL_COL_MID_G, BULB_WATERFALL_COL_MID_B);
        var _col_bri = make_colour_rgb(BULB_WATERFALL_COL_BRIGHT_R, BULB_WATERFALL_COL_BRIGHT_G, BULB_WATERFALL_COL_BRIGHT_B);
        var _col_deep = make_colour_rgb(
            max(0, BULB_WATERFALL_COL_BASE_R - 40),
            max(0, BULB_WATERFALL_COL_BASE_G - 55),
            max(20, BULB_WATERFALL_COL_BASE_B - 20)
        );

        var _surf_scroll = pond_surface_scroll;

        // Everything below is clipped to the camera: a 480px pool with a ~320px view was
        // building a third more geometry than could ever be seen.
        var _cam = view_camera[0];
        if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;
        var _vx0 = camera_get_view_x(_cam);
        var _vy0 = camera_get_view_y(_cam);
        var _vx1 = _vx0 + camera_get_view_width(_cam);
        var _vy1 = _vy0 + camera_get_view_height(_cam);

        for (var _i = 0; _i < array_length(pond_list); _i++) {
            var _p = pond_list[_i];
            var _b = scr_pond_draw_bounds(_p);
            if (_b.right < _vx0 || _b.left > _vx1) continue;
            if (_b.bottom < _vy0 || _b.top > _vy1) continue;

            // Bands stop short of the waterline by the most the surface can travel, so
            // the wavy top edge below is the only thing that defines where water starts.
            var _body_top = _b.top + scr_pond_surface_pad();
            var _bands = max(3, min(8, floor(_b.h / 10)));

            for (var _band = 0; _band < _bands; _band++) {
                var _t0 = _band / _bands;
                var _t1 = (_band + 1) / _bands;
                var _y0 = lerp(_body_top, _b.bottom, _t0);
                var _y1 = lerp(_body_top, _b.bottom, _t1);
                var _col = merge_colour(_col_mid, _col_deep, _t0);
                var _a = lerp(BULB_POND_BODY_ALPHA * 0.75, BULB_POND_DEEP_ALPHA, _t0);
                scr_pond_draw_faded_rect(_b.left, _y0, _b.right - 1, _y1 - 1, _col, _a);
            }

            // Waterline geometry: one strip for the body top (vertical alpha gradient
            // replaces what used to be a second "sheen" strip) and one for the foam line.
            // The waterline can never dip past _body_top because the pad accounts for the
            // wave clamp, so no sample needs skipping and the strips stay unbroken.
            var _cols = _b.w;
            var _fill_a = BULB_POND_BODY_ALPHA * 0.75;
            // Old look was a 0.45 sheen composited over the 0.75 fill near the surface.
            var _surf_a = _fill_a + BULB_POND_BODY_ALPHA * 0.45 * (1 - _fill_a);
            var _tick_phase = floor(_surf_scroll * 2);
            var _has_surface = variable_struct_exists(_p, "surface");

            var _cstep = max(1, BULB_POND_SURFACE_COLUMN_STEP);
            // Visible span, snapped out to whole steps and padded so the strip always
            // starts and ends off-screen rather than popping at the view edge.
            var _c0 = clamp(floor((_vx0 - _b.left) / _cstep - 1) * _cstep, 0, _cols);
            var _c1 = clamp(ceil((_vx1 - _b.left) / _cstep + 1) * _cstep, 0, _cols);
            var _samples = ceil((_c1 - _c0) / _cstep) + 1;
            if (_samples < 2) continue;

            // Arrays are sized for the whole pond once and reused, so panning the camera
            // never reallocates them.
            var _max_samples = ceil(_cols / _cstep) + 2;
            if (!variable_struct_exists(_p, "col_x") || array_length(_p.col_x) < _max_samples) {
                _p.col_x = array_create(_max_samples, 0);
                _p.col_sy = array_create(_max_samples, 0);
                _p.col_ef = array_create(_max_samples, 0);
            }
            var _col_x = _p.col_x;
            var _col_sy = _p.col_sy;
            var _col_ef = _p.col_ef;

            // scr_pond_surface_offset_at / _wave_at / _edge_fade_at are inlined below.
            // At ~200 samples a frame the call overhead was measurable on its own.
            var _surf = _has_surface ? _p.surface : undefined;
            var _surf_n = _has_surface ? array_length(_surf) : 0;
            var _wave_on = BULB_POND_WAVE_ENABLED && variable_struct_exists(_p, "wave") && !_p.wave_idle;
            var _wh = _wave_on ? _p.wave.h : undefined;
            var _wh_n = _wave_on ? array_length(_wh) : 0;
            var _wstep = BULB_POND_WAVE_STEP;
            var _swave = BULB_POND_SURFACE_WAVE;
            var _fade_f = min(BULB_POND_EDGE_FADE, floor(_cols / 2));
            var _top_y = _b.top;

            for (var _c = 0; _c < _samples; _c++) {
                var _lx = min(_c0 + _c * _cstep, _c1);
                _col_x[_c] = _lx;

                var _off = 0;
                if (_surf_n > 0) {
                    var _si = floor(_lx + _surf_scroll) mod _surf_n;
                    if (_si < 0) _si += _surf_n;
                    _off = _surf[_si] + round(sin((_lx * 0.18) + (_surf_scroll * 0.35)) * _swave);
                }
                if (_wh_n > 0) {
                    var _wc = _lx / _wstep;
                    var _wi0 = clamp(floor(_wc), 0, _wh_n - 1);
                    var _wi1 = clamp(_wi0 + 1, 0, _wh_n - 1);
                    _off += lerp(_wh[_wi0], _wh[_wi1], clamp(_wc - _wi0, 0, 1));
                }
                _col_sy[_c] = floor(_top_y + _off);

                var _ef = 1;
                if (_fade_f > 0) {
                    var _dd = min(_lx, _cols - 1 - _lx);
                    if (_dd < 0) {
                        _ef = 0;
                    } else if (_dd < _fade_f) {
                        _ef = (_dd + 1) / (_fade_f + 1);
                    }
                }
                _col_ef[_c] = _ef;
            }

            draw_primitive_begin(pr_trianglestrip);
            for (var _tx = 0; _tx < _samples; _tx++) {
                var _px = _b.left + _col_x[_tx];
                var _ef2 = _col_ef[_tx];
                draw_vertex_colour(_px, _col_sy[_tx], _col_mid, _surf_a * _ef2);
                draw_vertex_colour(_px, _body_top, _col_mid, _fill_a * _ef2);
            }
            draw_primitive_end();

            if (_has_surface) {
                draw_primitive_begin(pr_trianglestrip);
                for (var _sx = 0; _sx < _samples; _sx++) {
                    var _spx = _b.left + _col_x[_sx];
                    var _ssy = _col_sy[_sx];
                    var _sa = BULB_POND_SURFACE_ALPHA * _col_ef[_sx];
                    var _tick = (((_col_x[_sx] + _tick_phase) mod 6) == 0) ? 1 : 0;
                    draw_vertex_colour(_spx, _ssy - _tick, _col_bri, _sa);
                    draw_vertex_colour(_spx, _ssy + 1, _col_bri, _sa);
                }
                draw_primitive_end();
            }

            if (BULB_POND_SURFACE_DOT_ENABLED && variable_struct_exists(_p, "surface_dots")) {
                var _pw = max(1, _b.w);
                var _dot_n = array_length(_p.surface_dots);
                if (_dot_n > 0) {
                    draw_primitive_begin(pr_trianglelist);
                    for (var _d = 0; _d < _dot_n; _d++) {
                        var _dot = _p.surface_dots[_d];
                        var _dx = (_dot.ox + _surf_scroll * _dot.speed) mod _pw;
                        if (_dx < 0) _dx += _pw;

                        // Cull on X before paying for the surface sample.
                        var _dpx = floor(_b.left + _dx);
                        if (_dpx < _vx0 - 2 || _dpx > _vx1 + 2) continue;

                        var _ef_d = scr_pond_edge_fade_at(_b.left, _b.right, _dpx);
                        if (_ef_d <= 0) continue;

                        var _amp_d = scr_pond_surface_offset_at(_p, _dx, _surf_scroll);
                        var _bob = round(sin(_surf_scroll * 0.4 + _dot.phase) * 0.6);
                        var _dpy = floor(_b.top + _amp_d + _dot.bias + _bob);

                        var _dc = _dot.bright ? c_white : _col_bri;
                        var _da = BULB_POND_SURFACE_DOT_ALPHA * (_dot.bright ? 1 : 0.75) * _ef_d;
                        scr_pond_push_quad(_dpx, _dpy, _dpx + 1, _dpy + 1, _dc, _da);
                    }
                    draw_primitive_end();
                }
            }
        }

        if (BULB_POND_SPARKLE_ENABLED) {
            var _scroll = pond_scroll;
            for (var _j = 0; _j < array_length(pond_list); _j++) {
                var _pond = pond_list[_j];
                if (!variable_struct_exists(_pond, "sparkles")) continue;
                var _bb = scr_pond_draw_bounds(_pond);
                if (_bb.right < _vx0 || _bb.left > _vx1) continue;
                if (_bb.bottom < _vy0 || _bb.top > _vy1) continue;
                var _pw2 = max(1, _pond.w);
                var _ph = max(1, _pond.h);
                var _spk_n = array_length(_pond.sparkles);
                if (_spk_n <= 0) continue;

                draw_primitive_begin(pr_trianglelist);
                for (var _s2 = 0; _s2 < _spk_n; _s2++) {
                    var _sp = _pond.sparkles[_s2];
                    var _flow = variable_struct_exists(_sp, "flow_dir") ? _sp.flow_dir : 1;
                    var _ox = (_sp.ox + _scroll * _flow * 0.35) mod _pw2;
                    if (_ox < 0) _ox += _pw2;
                    var _oy = (_sp.oy - _scroll * 0.2) mod _ph;
                    if (_oy < 0) _oy += _ph;
                    if (_oy < 4) continue;

                    var _px2 = floor(_bb.left + (_bb.w * _ox / _pw2));
                    if (_px2 < _vx0 - 2 || _px2 > _vx1 + 2) continue;
                    var _py2 = floor(_pond.top + _oy);

                    var _ef_s = scr_pond_edge_fade_at(_bb.left, _bb.right, _px2);
                    if (_ef_s <= 0) continue;

                    var _sc = _sp.bright ? _col_bri : _col_mid;
                    var _sa2 = BULB_POND_SPARKLE_ALPHA * (_sp.bright ? 0.85 : 0.5) * _ef_s;
                    var _slen = (_sp.kind == 0) ? 1 : _sp.len;
                    scr_pond_push_quad(_px2, _py2, _px2 + 1, _py2 + _slen, _sc, _sa2);
                }
                draw_primitive_end();
            }
        }

        draw_set_alpha(_old_alpha);
        draw_set_color(_old_col);
        gpu_set_blendmode(_old_blend);
        gpu_set_texfilter(_old_tex);

        if (BULB_POND_DEBUG_PERF) {
            // Accumulated because Bulb may render the scene more than once per frame;
            // a call count above 1 means the layer script is running per pass.
            pond_perf_us_acc += (get_timer() - _perf_t0);
            pond_perf_calls_acc += 1;
        }
    }
}
