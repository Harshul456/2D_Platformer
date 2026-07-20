// --- Tile collision shapes (non–full-block / ledge art) ---
// Probe inside the cell using tile index + local pixel (lx, ly). Mirror/flip on the tile transform
// is applied to (lx, ly) before tests.
//
// TileSet2 / spr_test — indices **1**, **5**, **34**, **35**, **36**: one-way **walkable line** ledges.
// Hardcoded local X ranges (after mirror) + top band ly 0–3; no ellipse/fraction caps.
// Rising: global.player_move_vsp < 0 → ignored. Falling: one-way uses global.player_ledge_bb_prev with TILEMAP_LEDGE_ONEWAY_BELOW_SLACK so micro-sink still reads as "from above".
// Landing snap: tilemap_shelf_threshold_land_dy (+ magnet); side-entry: tilemap_shelf_side_entry_land_dy (min vsp, air frames, hsp intent, tighter _catch_win).


#macro TILEMAP_LEDGE_MAGNET_TOP_PX  5
#macro TILEMAP_LEDGE_ONEWAY_BELOW_SLACK  2.5

#macro TILECOL_SHAPE_FULL       0
#macro TILECOL_SHAPE_LEDGE_L45  1
#macro TILECOL_SHAPE_LEDGE_R45  2
#macro TILECOL_SHAPE_CAP_TL     3
#macro TILECOL_SHAPE_CAP_TR     4

#macro TILECOL_LEDGE_L45_IDX_LO  -1
#macro TILECOL_LEDGE_L45_IDX_HI  -1
#macro TILECOL_LEDGE_R45_IDX_LO  -1
#macro TILECOL_LEDGE_R45_IDX_HI  -1
#macro TILECOL_CAP_TL_IDX_LO     -1
#macro TILECOL_CAP_TL_IDX_HI     -1
#macro TILECOL_CAP_TR_IDX_LO     -1
#macro TILECOL_CAP_TR_IDX_HI     -1
#macro TILECOL_LEDGE_SLOPE_BIAS  0
#macro TILECOL_CAP_TL_W_FRAC      0.58
#macro TILECOL_CAP_TL_H_FRAC      0.38
#macro TILECOL_CAP_TL_USE_ELLIPSE 0

function tilecol_actor_vsp_get() {
    if (variable_global_exists("tilecol_actor_vsp")) return global.tilecol_actor_vsp;
    return variable_global_exists("player_move_vsp") ? global.player_move_vsp : 0;
}

function tilecol_actor_ledge_bb_prev_get() {
    if (variable_global_exists("tilecol_actor_ledge_bb_prev")) return global.tilecol_actor_ledge_bb_prev;
    return variable_global_exists("player_ledge_bb_prev") ? global.player_ledge_bb_prev : -1000000;
}

/// @function tilecol_sync_actor_context
/// @description Push per-actor vsp + prior bbox_bottom for one-way shelf tiles (indices 1,5,34,35,36).
function tilecol_sync_actor_context(_vsp, _ledge_bb_prev) {
    global.tilecol_actor_vsp = _vsp;
    global.tilecol_actor_ledge_bb_prev = _ledge_bb_prev;
}

/// Shelf indices 1/5/34/35/36: true only when probe hits the walkable cap band (not empty lip in same cell).
function tilemap_point_on_shelf_walkable_cap(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    if (!tilecol_one_way_shelf_tile_index(idx)) return false;
    if (tilemap_cell_above_is_solid(_tm, _px, _py)) return false; // buried cap = wall, not a walkable top
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_left = tilemap_get_x(_tm) + tcx * tw;
    var cell_top = tilemap_get_y(_tm) + tcy * th;
    var lx = _px - cell_left;
    var ly = _py - cell_top;
    if (tile_get_mirror(td)) lx = tw - 1 - lx;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    return tilecol_one_way_cap_shelf_hit(idx, lx, ly, tw, th);
}

function tilecol_shape_for_tile_index(_idx) {
    switch (_idx) {
        case 1: return TILECOL_SHAPE_CAP_TR;
        case 5: return TILECOL_SHAPE_CAP_TL;
        case 34: return TILECOL_SHAPE_CAP_TL;
        case 35: return TILECOL_SHAPE_FULL;
        case 36: return TILECOL_SHAPE_CAP_TR;
    }
    if (TILECOL_CAP_TL_IDX_LO >= 0 && _idx >= TILECOL_CAP_TL_IDX_LO && _idx <= TILECOL_CAP_TL_IDX_HI) {
        return TILECOL_SHAPE_CAP_TL;
    }
    if (TILECOL_CAP_TR_IDX_LO >= 0 && _idx >= TILECOL_CAP_TR_IDX_LO && _idx <= TILECOL_CAP_TR_IDX_HI) {
        return TILECOL_SHAPE_CAP_TR;
    }
    if (TILECOL_LEDGE_L45_IDX_LO >= 0 && _idx >= TILECOL_LEDGE_L45_IDX_LO && _idx <= TILECOL_LEDGE_L45_IDX_HI) {
        return TILECOL_SHAPE_LEDGE_L45;
    }
    if (TILECOL_LEDGE_R45_IDX_LO >= 0 && _idx >= TILECOL_LEDGE_R45_IDX_LO && _idx <= TILECOL_LEDGE_R45_IDX_HI) {
        return TILECOL_SHAPE_LEDGE_R45;
    }
    return TILECOL_SHAPE_FULL;
}

function tilecol_solid_cap_tl_wf(_lx, _ly, _tw, _th, _wf) {
    var hf = TILECOL_CAP_TL_H_FRAC;
    if (TILECOL_CAP_TL_USE_ELLIPSE) {
        var ax = max(1, _tw * _wf);
        var ay = max(1, _th * hf);
        return ((_lx * _lx) / (ax * ax) + (_ly * _ly) / (ay * ay)) <= 1.0001;
    }
    return _lx < _tw * _wf && _ly < _th * hf;
}

function tilecol_solid_cap_tl(_lx, _ly, _tw, _th) {
    return tilecol_solid_cap_tl_wf(_lx, _ly, _tw, _th, TILECOL_CAP_TL_W_FRAC);
}

function tilecol_solid_cap_tr_wf(_lx, _ly, _tw, _th, _wf) {
    var lx2 = _tw - 1 - _lx;
    return tilecol_solid_cap_tl_wf(lx2, _ly, _tw, _th, _wf);
}

function tilecol_solid_cap_tr(_lx, _ly, _tw, _th) {
    return tilecol_solid_cap_tr_wf(_lx, _ly, _tw, _th, TILECOL_CAP_TL_W_FRAC);
}

function tilecol_one_way_shelf_tile_index(_idx) {
    return (_idx == 1 || _idx == 5 || _idx == 34 || _idx == 35 || _idx == 36);
}

/// True if the cell directly ABOVE (_px,_py)'s cell contains any collision tile.
/// A genuine walkable platform top always has open air above it, so a shelf/cap tile WITH a tile above
/// it isn't a platform — it's buried in a wall mass.
function tilemap_cell_above_is_solid(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var th = tilemap_get_tile_height(_tm);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    if (tcy <= 0) return false;
    var cell_top = tilemap_get_y(_tm) + tcy * th;
    return tilemap_get_at_pixel(_tm, _px, cell_top - 1) != 0;
}

/// Option A — "buried cap": a one-way shelf/cap tile that has a tile directly above it. Treated as a
/// FULL solid block everywhere (blocks from all sides, full-cell solidity, excluded from platform/cap
/// ground logic) so walls built from cap art behave like solid walls instead of climbable corners.
function tilemap_shelf_tile_is_buried(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    if (!tilecol_one_way_shelf_tile_index(tile_get_index(td))) return false;
    return tilemap_cell_above_is_solid(_tm, _px, _py);
}

/// True if a 1px step in `_dir` would leave shelf feet with no floor/shelf support.
/// Used to kill jump→land momentum into the empty lip of tiles 1/5/34/36 (no position snap).
function tilemap_shelf_step_into_void(_tm, _pl, _pc, _pr, _feet_y, _dir) {
    if (_tm == noone || _tm == -1 || _dir == 0) return false;
    if (!tilemap_shelf_cap_near_feet(_tm, _pl, _pc, _pr, _feet_y)) {
        // Airborne landing window: shelf just below feet.
        var _near = false;
        for (var _dy = 1; _dy <= 14; _dy++) {
            if (tilemap_shelf_cap_near_feet(_tm, _pl, _pc, _pr, _feet_y + _dy)) {
                _near = true;
                _feet_y = _feet_y + _dy;
                break;
            }
        }
        if (!_near) return false;
    }

    var _pl2 = _pl + _dir;
    var _pc2 = _pc + _dir;
    var _pr2 = _pr + _dir;
    var _fy1 = _feet_y + 1;
    var _fy2 = _feet_y + 2;
    var _supported = tilemap_point_on_shelf_walkable_cap(_tm, _pl2, _fy1)
        || tilemap_point_on_shelf_walkable_cap(_tm, _pc2, _fy1)
        || tilemap_point_on_shelf_walkable_cap(_tm, _pr2, _fy1)
        || tilemap_point_on_shelf_walkable_cap(_tm, _pl2, _fy2)
        || tilemap_point_on_shelf_walkable_cap(_tm, _pc2, _fy2)
        || tilemap_point_on_shelf_walkable_cap(_tm, _pr2, _fy2)
        || tilemap_point_solid(_tm, _pl2, _fy1) || tilemap_point_solid(_tm, _pc2, _fy1) || tilemap_point_solid(_tm, _pr2, _fy1);
    return !_supported;
}

/// Walkable solid X in tile-local space (after mirror). Right edge "32" in art notes = exclusive → last lx = tw-1.
function tilemap_ledge_walkable_x(_idx, _lx, _tw) {
    var _r = tilemap_ledge_walkable_range(_idx, _tw);
    if (_r.lo < 0) return false;
    return (_lx >= _r.lo && _lx <= _r.hi);
}

/// @returns {Struct} { lo, hi } local walkable X inclusive, or lo=-1 if not a shelf.
function tilemap_ledge_walkable_range(_idx, _tw) {
    switch (_idx) {
        case 1:  return { lo: 12, hi: 31 };
        case 5:  return { lo: 0,  hi: 20 };
        case 34: return { lo: 16, hi: 31 };
        case 36: return { lo: 0,  hi: 16 };
        case 35: return { lo: 0,  hi: _tw - 1 };
        default: return { lo: -1, hi: -1 };
    }
}

function tilecol_one_way_shelf_max_ly(_idx) {
    return 3;
}

/// @param {real} _probe_y Absolute pixel Y (e.g. feet_y + GROUND_CHECK_DIST)
function tilemap_shelf_index_at_pixel(_tm, _px, _probe_y) {
    if (_tm == noone) return -1;
    var td = tilemap_get_at_pixel(_tm, _px, _probe_y);
    if (td == 0) return -1;
    var ix = tile_get_index(td);
    if (!tilecol_one_way_shelf_tile_index(ix)) return -1;
    if (tilemap_cell_above_is_solid(_tm, _px, _probe_y)) return -1; // buried cap = full block, not a shelf
    return ix;
}

/// Toe-only shelf cap (indices 1/5/34/36) — ignores center probe so knockback off lip cannot hover.
function tilemap_shelf_cap_under_toes(_tm, _pl, _pr, _feet_y) {
    if (_tm == noone || _tm == -1) return false;
    for (var _dj = -1; _dj <= 2; _dj++) {
        var _py = _feet_y + _dj;
        if (tilemap_point_on_shelf_walkable_cap(_tm, _pl, _py)) return true;
        if (tilemap_point_on_shelf_walkable_cap(_tm, _pr, _py)) return true;
    }
    return false;
}

/// True when L/C/R feet probes hit the *cap* solid of a one-way shelf (not empty air in the same 32px cell).
/// Used for downward collision when `grounded` is false on strict 34/36 lips — the airborne branch otherwise ignores shelves.
function tilemap_shelf_cap_near_feet(_tm, _pl, _pc, _pr, _feet_y) {
    if (_tm == noone || _tm == -1) return false;
    for (var _dj = -1; _dj <= 2; _dj++) {
        var _py = _feet_y + _dj;
        if (tilemap_cell_thin_floor_tile(_tm, _pl, _py) && tilemap_shelf_index_at_pixel(_tm, _pl, _py) != -1) return true;
        if (tilemap_cell_thin_floor_tile(_tm, _pc, _py) && tilemap_shelf_index_at_pixel(_tm, _pc, _py) != -1) return true;
        if (tilemap_cell_thin_floor_tile(_tm, _pr, _py) && tilemap_shelf_index_at_pixel(_tm, _pr, _py) != -1) return true;
    }
    return false;
}

/// One-way ledge land: vsp>0, bbox_bottom_prev above cell top, next_bb crosses rest line; lx must be walkable.
/// Optional _mag_dir in [-1,1]: when near the top (≤ TILEMAP_LEDGE_MAGNET_TOP_PX) and moving horizontally toward the lip, try ±1..±3 px probes.
/// Returns dy so bbox_bottom lands on cell_top-1 (geometric; no floor on y).
function tilemap_shelf_threshold_land_dy(_tm, _pl, _pc, _pr, _bb_now, _bb_prev_frame, _vsp) {
    var _mag_dir = 0;
    if (argument_count > 7) _mag_dir = clamp(argument[7], -1, 1);
    if (_tm == noone || _vsp <= 0) return noone;
    var next_bb = _bb_now + _vsp;
    var tmy = tilemap_get_y(_tm);
    var tmx = tilemap_get_x(_tm);
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var _best_top = noone;
    var _y_lo = floor(min(_bb_now, next_bb));
    var _y_hi = ceil(max(_bb_now, next_bb));
    for (var _fi = 0; _fi < 3; _fi++) {
        var _px0 = (_fi == 0) ? _pl : ((_fi == 1) ? _pc : _pr);
        for (var _md = 0; _md < 4; _md++) {
            if (_md > 0 && _mag_dir == 0) break;
            var _px = _px0 + _mag_dir * _md;
            for (var _py = _y_lo; _py <= _y_hi; _py++) {
                var td = tilemap_get_at_pixel(_tm, _px, _py);
                if (td == 0) continue;
                var idx = tile_get_index(td);
                if (!tilecol_one_way_shelf_tile_index(idx)) continue;
                var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
                var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
                var cell_left = tmx + tcx * tw;
                var cell_top = tmy + tcy * th;
                if (_md > 0 && !(min(abs(_bb_now - cell_top), abs(next_bb - cell_top)) <= TILEMAP_LEDGE_MAGNET_TOP_PX)) continue;
                if (!(_bb_prev_frame < cell_top + TILEMAP_LEDGE_ONEWAY_BELOW_SLACK)) continue;
                if (!(next_bb >= cell_top - 1)) continue;
                var lx_top = _px - cell_left;
                var ly_top = _py - cell_top;
                if (tile_get_mirror(td)) lx_top = tw - 1 - lx_top;
                if (tile_get_flip(td)) ly_top = th - 1 - ly_top;
                if (!tilecol_one_way_cap_shelf_hit(idx, lx_top, ly_top, tw, th)) continue;
                if (_best_top == noone || cell_top < _best_top) _best_top = cell_top;
            }
        }
    }
    if (_best_top == noone) return noone;
    return (_best_top - 1) - _bb_now;
}

/// Universal corner catch (side-entry): bbox within _catch_win of a top lip; _h_intent is −1/0/+1 from input (or sign(hsp) fallback), used with _player_cx to pick ledges toward motion.
function tilemap_shelf_side_entry_land_dy(_tm, _pl, _pc, _pr, _bb_now, _catch_win, _h_intent, _player_cx) {
    if (_tm == noone || _tm == -1) return noone;
    var tmy = tilemap_get_y(_tm);
    var tmx = tilemap_get_x(_tm);
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var _best_top = noone;
    var _y_lo = floor(_bb_now - _catch_win);
    var _y_hi = ceil(_bb_now + 1);
    for (var _fi = 0; _fi < 3; _fi++) {
        var _px = (_fi == 0) ? _pl : ((_fi == 1) ? _pc : _pr);
        for (var _py = _y_lo; _py <= _y_hi; _py++) {
            var td = tilemap_get_at_pixel(_tm, _px, _py);
            if (td == 0) continue;
            var idx = tile_get_index(td);
            var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
            var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
            var cell_left = tmx + tcx * tw;
            var cell_top = tmy + tcy * th;
            if (abs(_bb_now - cell_top) > _catch_win) continue;
            var lx_top = _px - cell_left;
            var ly_top = _py - cell_top;
            if (tile_get_mirror(td)) lx_top = tw - 1 - lx_top;
            if (tile_get_flip(td)) ly_top = th - 1 - ly_top;
            if (!tilemap_corner_catch_top_surface_hit(idx, lx_top, ly_top, tw, th, _catch_win)) continue;
            var _cell_cx = cell_left + tw * 0.5;
            if (_h_intent > 0 && !(_cell_cx > _player_cx)) continue;
            if (_h_intent < 0 && !(_cell_cx < _player_cx)) continue;
            if (_best_top == noone || cell_top < _best_top) _best_top = cell_top;
        }
    }
    if (_best_top == noone) return noone;
    return (_best_top - 1) - _bb_now;
}

/// Shelf walk surface: top band (ly) only; horizontal extent = walkable lx table.
function tilecol_one_way_cap_shelf_hit(_idx, _lx, _ly, _tw, _th) {
    if (!tilecol_one_way_shelf_tile_index(_idx)) return false;
    if (_ly < 0 || _ly > tilecol_one_way_shelf_max_ly(_idx)) return false;
    return tilemap_ledge_walkable_x(_idx, _lx, _tw);
}

function tilecol_solid_at_local(_shape, _lx, _ly, _tw, _th, _idx) {
    switch (_shape) {
        case TILECOL_SHAPE_FULL:
            return true;
        case TILECOL_SHAPE_LEDGE_L45:
            return _ly <= _lx + TILECOL_LEDGE_SLOPE_BIAS;
        case TILECOL_SHAPE_LEDGE_R45:
            return _ly <= (_tw - 1 - _lx) + TILECOL_LEDGE_SLOPE_BIAS;
        case TILECOL_SHAPE_CAP_TL: {
            var wf = TILECOL_CAP_TL_W_FRAC;
            return tilecol_solid_cap_tl_wf(_lx, _ly, _tw, _th, wf);
        }
        case TILECOL_SHAPE_CAP_TR: {
            var wftr = TILECOL_CAP_TL_W_FRAC;
            return tilecol_solid_cap_tr_wf(_lx, _ly, _tw, _th, wftr);
        }
    }
    return true;
}

/// True if (lx,ly) is a "top lip" sample for corner snap / horizontal mount (shelves: walkable cap; full blocks: top band; caps: art-consistent band).
function tilemap_corner_catch_top_surface_hit(_idx, _lx, _ly, _tw, _th, _win_px) {
    if (tilecol_one_way_shelf_tile_index(_idx)) {
        return tilecol_one_way_cap_shelf_hit(_idx, _lx, _ly, _tw, _th);
    }
    var sh = tilecol_shape_for_tile_index(_idx);
    if (!tilecol_solid_at_local(sh, _lx, _ly, _tw, _th, _idx)) return false;
    var _band = max(_win_px, 4);
    switch (sh) {
        case TILECOL_SHAPE_FULL:
            return _ly <= _band;
        case TILECOL_SHAPE_CAP_TL:
        case TILECOL_SHAPE_CAP_TR:
            return _ly <= max(_band, ceil(_th * TILECOL_CAP_TL_H_FRAC) + 1);
        default:
            return _ly <= _band;
    }
}

/// @param {bool} [_rising_through]
/// @param {real} [_actor_bbox_bottom] floor(bbox_bottom); legacy, ledges use global.player_ledge_bb_prev
/// @param {bool} [_ignore_shelf_ledge] when true, ledge indices are not solid (fall handled by threshold land_dy)
function tilemap_point_solid(_tm, _px, _py) {
    var _rising = false;
    var _feet_b = noone;
    var _ignore_shelf = false;
    if (argument_count > 3) _rising = argument[3];
    if (argument_count > 4) _feet_b = argument[4];
    if (argument_count > 5) _ignore_shelf = argument[5];
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_left = tilemap_get_x(_tm) + tcx * tw;
    var cell_top = tilemap_get_y(_tm) + tcy * th;
    var lx = _px - cell_left;
    var ly = _py - cell_top;
    if (tile_get_mirror(td)) lx = tw - 1 - lx;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    var idx = tile_get_index(td);
    // Buried cap = wall mass (tile directly above): full solid block from every direction. Checked
    // before _ignore_shelf so downward pass-through logic can't tunnel through a cap-built wall.
    if (tilecol_one_way_shelf_tile_index(idx) && tilemap_cell_above_is_solid(_tm, _px, _py)) {
        return true;
    }
    if (_ignore_shelf && tilecol_one_way_shelf_tile_index(idx)) return false;
    if (tilecol_one_way_shelf_tile_index(idx)) {
        if (tilecol_actor_vsp_get() < 0) return false;
        if (!tilecol_one_way_cap_shelf_hit(idx, lx, ly, tw, th)) return false;
        var _prevbb = tilecol_actor_ledge_bb_prev_get();
        if (_prevbb >= cell_top + TILEMAP_LEDGE_ONEWAY_BELOW_SLACK) return false;
        return true;
    }
    var sh = tilecol_shape_for_tile_index(idx);
    return tilecol_solid_at_local(sh, lx, ly, tw, th, idx);
}

function tilemap_cell_shape_is_cap(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var sh = tilecol_shape_for_tile_index(tile_get_index(td));
    return (sh == TILECOL_SHAPE_CAP_TL || sh == TILECOL_SHAPE_CAP_TR);
}

function tilemap_cell_thin_floor_tile(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    if (tilecol_one_way_shelf_tile_index(idx)) {
        if (tilemap_cell_above_is_solid(_tm, _px, _py)) return false; // buried cap = full block, not a thin floor
        var tw = tilemap_get_tile_width(_tm);
        var th = tilemap_get_tile_height(_tm);
        var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
        var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
        var cell_left = tilemap_get_x(_tm) + tcx * tw;
        var cell_top = tilemap_get_y(_tm) + tcy * th;
        var lx = _px - cell_left;
        var ly = _py - cell_top;
        if (tile_get_mirror(td)) lx = tw - 1 - lx;
        if (tile_get_flip(td)) ly = th - 1 - ly;
        return tilecol_one_way_cap_shelf_hit(idx, lx, ly, tw, th);
    }
    var sh = tilecol_shape_for_tile_index(idx);
    return (sh == TILECOL_SHAPE_CAP_TL || sh == TILECOL_SHAPE_CAP_TR);
}

function tilemap_cell_thin_floor_near_feet(_tm, _px, _feet_y) {
    if (_tm == noone || _tm == -1) return false;
    return tilemap_cell_thin_floor_tile(_tm, _px, _feet_y - 1) ||
        tilemap_cell_thin_floor_tile(_tm, _px, _feet_y) ||
        tilemap_cell_thin_floor_tile(_tm, _px, _feet_y + 1) ||
        tilemap_cell_thin_floor_tile(_tm, _px, _feet_y + 2);
}

/// True if (_px,_py) is solid on the top _band_px rows of a TILECOL_SHAPE_FULL cell (flat platform top — not shelf/cap).
/// Used for softer air peel at full-block lips.
function tilemap_point_full_block_top_band(_tm, _px, _py, _band_px) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    if (tilecol_one_way_shelf_tile_index(idx)) return false;
    if (tilecol_shape_for_tile_index(idx) != TILECOL_SHAPE_FULL) return false;
    if (!tilemap_point_solid(_tm, _px, _py)) return false;
    var th = tilemap_get_tile_height(_tm);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_top = tilemap_get_y(_tm) + tcy * th;
    var ly = _py - cell_top;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    return ly >= 0 && ly <= _band_px;
}

/// True if a horizontal probe would block; false if empty, or feet within _ledge_win of this cell's top on a top lip (all tile types).
function tilemap_horizontal_side_probe_blocks(_tm, _px, _py, _bbox_bottom, _ledge_win) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var tmy = tilemap_get_y(_tm);
    var tmx = tilemap_get_x(_tm);
    var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _py);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_left = tmx + tcx * tw;
    var cell_top = tmy + tcy * th;
    var lx = _px - cell_left;
    var ly = _py - cell_top;
    if (tile_get_mirror(td)) lx = tw - 1 - lx;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    var idx = tile_get_index(td);
    // Buried cap = wall: never grant the ledge-window "mountable top" exemption — always block.
    if (!tilemap_cell_above_is_solid(_tm, _px, _py)
        && abs(_bbox_bottom - cell_top) <= _ledge_win
        && tilemap_corner_catch_top_surface_hit(idx, lx, ly, tw, th, _ledge_win)) return false;
    return check_tile_collision(_px, _py);
}

/// When moving into column _px while airborne, true if the sample hits a full-block side face (not just the top band).
/// Prevents ledge-window logic from letting the player clip into vertical walls near tile tops.
function tilemap_horizontal_full_block_side_face_at(_tm, _px, _py, _bbox_bottom, _win) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    // A buried cap counts as a full-block face here (so the airborne ledge-mount treats a cap-built
    // wall as a wall). A non-buried cap/shelf is not a full-block face.
    var _buried_face = tilecol_one_way_shelf_tile_index(idx) && tilemap_cell_above_is_solid(_tm, _px, _py);
    if (tilecol_one_way_shelf_tile_index(idx) && !_buried_face) return false;
    if (!_buried_face && tilecol_shape_for_tile_index(idx) != TILECOL_SHAPE_FULL) return false;
    var th = tilemap_get_tile_height(_tm);
    var tmy = tilemap_get_y(_tm);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_top = tmy + tcy * th;
    var ly = _py - cell_top;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    var _band = max(_win, 4);
    if (ly > _band) return true;
    if (_bbox_bottom > cell_top + _win) return true;
    return false;
}

/// True when a point on the feet row is solid full-block AND is inside the tile body (below the top band).
function tilemap_point_full_block_feet_embedded(_tm, _px, _py, _ly_embed_min) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    if (tilecol_one_way_shelf_tile_index(idx)) return false;
    if (tilecol_shape_for_tile_index(idx) != TILECOL_SHAPE_FULL) return false;
    if (!tilemap_point_solid(_tm, _px, _py)) return false;
    var th = tilemap_get_tile_height(_tm);
    var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _py);
    var cell_top = tilemap_get_y(_tm) + tcy * th;
    var ly = _py - cell_top;
    if (tile_get_flip(td)) ly = th - 1 - ly;
    return ly >= _ly_embed_min;
}

/// True when a pixel sits inside a solid FULL-block tile (ignores one-way shelves + non-full shapes).
/// Used for edge-clip recovery — a flush wall rest leaves the edge pixel in air, so this only trips on a real embed.
function tilemap_point_full_block_solid(_tm, _px, _py) {
    if (_tm == noone || _tm == -1) return false;
    var td = tilemap_get_at_pixel(_tm, _px, _py);
    if (td == 0) return false;
    var idx = tile_get_index(td);
    var _buried = tilecol_one_way_shelf_tile_index(idx) && tilemap_cell_above_is_solid(_tm, _px, _py);
    if (tilecol_one_way_shelf_tile_index(idx) && !_buried) return false;
    if (!_buried && tilecol_shape_for_tile_index(idx) != TILECOL_SHAPE_FULL) return false;
    return tilemap_point_solid(_tm, _px, _py);
}

/// Any of the usual feet probes (or raw bbox L/R) embedded in a full block below the top band.
function tilemap_any_feet_row_full_block_embedded(_tm, _pl, _pc, _pr, _bbox_left, _bbox_right, _feet_y, _ly_embed_min) {
    return tilemap_point_full_block_feet_embedded(_tm, _pl, _feet_y, _ly_embed_min) ||
        tilemap_point_full_block_feet_embedded(_tm, _pc, _feet_y, _ly_embed_min) ||
        tilemap_point_full_block_feet_embedded(_tm, _pr, _feet_y, _ly_embed_min) ||
        tilemap_point_full_block_feet_embedded(_tm, _bbox_left, _feet_y, _ly_embed_min) ||
        tilemap_point_full_block_feet_embedded(_tm, _bbox_right, _feet_y, _ly_embed_min);
}

/// Any solid along the wall column (y span) on a top lip whose cell_top is within _win of bbox_bottom — geometry-based (all tiles; shelves don’t depend on one-way check_tile).
function tilemap_horizontal_ledge_mount_priority(_tm, _wall_x, _bbox_bottom, _y_a, _y_b, _win) {
    if (_tm == noone || _tm == -1) return false;
    var _y_lo = min(_y_a, _y_b);
    var _y_hi = max(_y_a, _y_b);
    var th = tilemap_get_tile_height(_tm);
    var tmy = tilemap_get_y(_tm);
    var tmx = tilemap_get_x(_tm);
    var tw = tilemap_get_tile_width(_tm);
    for (var _py = _y_lo; _py <= _y_hi; _py++) {
        var td = tilemap_get_at_pixel(_tm, _wall_x, _py);
        if (td == 0) continue;
        var idx = tile_get_index(td);
        // Buried cap = wall mass, not a mountable ledge top — skip it.
        if (tilecol_one_way_shelf_tile_index(idx) && tilemap_cell_above_is_solid(_tm, _wall_x, _py)) continue;
        var tcx = tilemap_get_cell_x_at_pixel(_tm, _wall_x, _py);
        var tcy = tilemap_get_cell_y_at_pixel(_tm, _wall_x, _py);
        var cell_left = tmx + tcx * tw;
        var cell_top = tmy + tcy * th;
        if (abs(_bbox_bottom - cell_top) > _win) continue;
        var lx = _wall_x - cell_left;
        var ly = _py - cell_top;
        if (tile_get_mirror(td)) lx = tw - 1 - lx;
        if (tile_get_flip(td)) ly = th - 1 - ly;
        if (!tilemap_corner_catch_top_surface_hit(idx, lx, ly, tw, th, _win)) continue;
        return true;
    }
    return false;
}

/// When a downward step hits a ledge, snap so bbox_bottom = cell_top - 1 (geometric dy; avoids floor(y) jitter).
function tilemap_ledge_down_snap_dy(_tm, _pl, _pc, _pr, _probe_y, _bbox_bottom) {
    if (_tm == noone || _tm == -1) return noone;
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var tmx = tilemap_get_x(_tm);
    var tmy = tilemap_get_y(_tm);
    var _prevbb = tilecol_actor_ledge_bb_prev_get();
    for (var _fi = 0; _fi < 3; _fi++) {
        var _px = (_fi == 0) ? _pl : ((_fi == 1) ? _pc : _pr);
        var td = tilemap_get_at_pixel(_tm, _px, _probe_y);
        if (td == 0) continue;
        var idx = tile_get_index(td);
        if (!tilecol_one_way_shelf_tile_index(idx)) continue;
        var tcx = tilemap_get_cell_x_at_pixel(_tm, _px, _probe_y);
        var tcy = tilemap_get_cell_y_at_pixel(_tm, _px, _probe_y);
        var cell_left = tmx + tcx * tw;
        var cell_top = tmy + tcy * th;
        if (_prevbb >= cell_top + TILEMAP_LEDGE_ONEWAY_BELOW_SLACK) continue;
        var lx = _px - cell_left;
        var ly = _probe_y - cell_top;
        if (tile_get_mirror(td)) lx = tw - 1 - lx;
        if (tile_get_flip(td)) ly = th - 1 - ly;
        if (!tilecol_one_way_cap_shelf_hit(idx, lx, ly, tw, th)) continue;
        return (cell_top - 1) - _bbox_bottom;
    }
    return noone;
}

function tilemap_bbox_overlaps_solid(_tm, _l, _t, _r, _b) {
    if (_tm == noone || _tm == -1) return false;
    if (_l > _r || _t > _b) return false;
    var tw = tilemap_get_tile_width(_tm);
    var th = tilemap_get_tile_height(_tm);
    var tmx = tilemap_get_x(_tm);
    var tmy = tilemap_get_y(_tm);
    var c0 = min(
        tilemap_get_cell_x_at_pixel(_tm, _l, _t), tilemap_get_cell_x_at_pixel(_tm, _l, _b),
        tilemap_get_cell_x_at_pixel(_tm, _r, _t), tilemap_get_cell_x_at_pixel(_tm, _r, _b));
    var c1 = max(
        tilemap_get_cell_x_at_pixel(_tm, _l, _t), tilemap_get_cell_x_at_pixel(_tm, _l, _b),
        tilemap_get_cell_x_at_pixel(_tm, _r, _t), tilemap_get_cell_x_at_pixel(_tm, _r, _b));
    var r0 = min(
        tilemap_get_cell_y_at_pixel(_tm, _l, _t), tilemap_get_cell_y_at_pixel(_tm, _l, _b),
        tilemap_get_cell_y_at_pixel(_tm, _r, _t), tilemap_get_cell_y_at_pixel(_tm, _r, _b));
    var r1 = max(
        tilemap_get_cell_y_at_pixel(_tm, _l, _t), tilemap_get_cell_y_at_pixel(_tm, _l, _b),
        tilemap_get_cell_y_at_pixel(_tm, _r, _t), tilemap_get_cell_y_at_pixel(_tm, _r, _b));
    for (var cx = c0; cx <= c1; cx++) {
        for (var cy = r0; cy <= r1; cy++) {
            var cl = tmx + cx * tw;
            var ct = tmy + cy * th;
            var cr = cl + tw - 1;
            var cb = ct + th - 1;
            var il = max(_l, cl);
            var it = max(_t, ct);
            var ir = min(_r, cr);
            var ib = min(_b, cb);
            if (il > ir || it > ib) continue;
            for (var ix = 0; ix <= 3; ix++) {
                var sx = floor(lerp(il, ir, ix / 3));
                for (var iy = 0; iy <= 3; iy++) {
                    var sy = floor(lerp(it, ib, iy / 3));
                    if (tilemap_point_solid(_tm, sx, sy)) return true;
                }
            }
        }
    }
    return false;
}

function check_tile_collision(_x, _y) {
    var _rising = false;
    var _feet_b = noone;
    var _ignore_shelf = false;
    if (argument_count > 2) _rising = argument[2];
    if (argument_count > 3) _feet_b = argument[3];
    if (argument_count > 4) _ignore_shelf = argument[4];
    if (global.tilemap_collision_id == noone) return false;
    return tilemap_point_solid(global.tilemap_collision_id, _x, _y, _rising, _feet_b, _ignore_shelf);
}

function check_floor_standable(_px, _feet_y, _dist, _embed_px) {
    if (global.tilemap_collision_id == noone) return false;
    if (!check_tile_collision(_px, _feet_y + _dist)) return false;
    if (_embed_px > 0) {
        var _tdf = tilemap_get_at_pixel(global.tilemap_collision_id, _px, _feet_y + _dist);
        if (_tdf != 0 && tilecol_one_way_shelf_tile_index(tile_get_index(_tdf))) {
            return true;
        }
        if (check_tile_collision(_px, _feet_y) && check_tile_collision(_px, _feet_y - _embed_px)) return false;
    }
    return true;
}
