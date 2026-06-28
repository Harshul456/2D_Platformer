/// @description Does this tilemap cell contain a tile?
function scr_bulb_tilemap_cell_occupied(_tm, _cell_x, _cell_y) {
    if (_tm == noone || _tm == -1) return false;

    var _w = tilemap_get_width(_tm);
    var _h = tilemap_get_height(_tm);
    if (_cell_x < 0 || _cell_y < 0 || _cell_x >= _w || _cell_y >= _h) return false;

    return tilemap_get(_tm, _cell_x, _cell_y) != 0;
}

/// @description Shadow bake mode per cell on lay_collision only.
/// Platforms/ledges (1,5,34,35,36) and caps never cast — only full solid blocks.
function scr_bulb_tilemap_cell_occlude_style(_tm, _cell_x, _cell_y, _occlude_mode) {
    if (!scr_bulb_tilemap_cell_occupied(_tm, _cell_x, _cell_y)) return "none";
    if (_occlude_mode != "lay_collision") return "none";

    var _idx = tile_get_index(tilemap_get(_tm, _cell_x, _cell_y));
    if (tilecol_one_way_shelf_tile_index(_idx)) return "none";
    if (tilecol_shape_for_tile_index(_idx) == TILECOL_SHAPE_FULL) return "full";
    return "none";
}

function scr_bulb_tilemap_cell_blocks_light(_tm, _cell_x, _cell_y, _occlude_mode) {
    return scr_bulb_tilemap_cell_occlude_style(_tm, _cell_x, _cell_y, _occlude_mode) == "full";
}

function scr_bulb_tilemap_cell_occluder_rect(_tm, _cell_x, _cell_y) {
    var _tw = tilemap_get_tile_width(_tm);
    var _th = tilemap_get_tile_height(_tm);
    var _ox = tilemap_get_x(_tm);
    var _oy = tilemap_get_y(_tm);

    var _left = _ox + _cell_x * _tw;
    var _top = _oy + _cell_y * _th;
    return { l: _left, t: _top, r: _left + _tw, b: _top + _th };
}

function scr_bulb_get_collision_tilemap(_layer_name = "lay_collision") {
    if (_layer_name == "lay_collision"
        && variable_global_exists("tilemap_collision_id")
        && global.tilemap_collision_id != noone) {
        return global.tilemap_collision_id;
    }

    var _layer = layer_get_id(_layer_name);
    if (_layer == -1) return noone;
    return layer_tilemap_get_id(_layer);
}

function scr_bulb_tilemap_append_occluder_edges(_occluder, _tm, _occlude_mode) {
    var _w = tilemap_get_width(_tm);
    var _h = tilemap_get_height(_tm);

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            if (scr_bulb_tilemap_cell_occlude_style(_tm, _cx, _cy, _occlude_mode) != "full") continue;

            var _rect = scr_bulb_tilemap_cell_occluder_rect(_tm, _cx, _cy);
            var _left = _rect.l;
            var _top = _rect.t;
            var _right = _rect.r;
            var _bottom = _rect.b;

            if (!scr_bulb_tilemap_cell_blocks_light(_tm, _cx, _cy - 1, _occlude_mode)) {
                _occluder.AddEdge(_left, _top, _right, _top);
            }
            if (!scr_bulb_tilemap_cell_blocks_light(_tm, _cx + 1, _cy, _occlude_mode)) {
                _occluder.AddEdge(_right, _top, _right, _bottom);
            }
            if (!scr_bulb_tilemap_cell_blocks_light(_tm, _cx, _cy + 1, _occlude_mode)) {
                _occluder.AddEdge(_right, _bottom, _left, _bottom);
            }
            if (!scr_bulb_tilemap_cell_blocks_light(_tm, _cx - 1, _cy, _occlude_mode)) {
                _occluder.AddEdge(_left, _bottom, _left, _top);
            }
        }
    }
}

function scr_bulb_build_tilemap_occluders(_renderer, _layer_name = "lay_collision", _occlude_mode = "lay_collision") {
    if (_renderer == undefined) return undefined;

    var _tm = scr_bulb_get_collision_tilemap(_layer_name);
    if (_tm == noone || _tm == -1) return undefined;

    var _occluder = new BulbStaticOccluder(_renderer);
    _occluder.visible = true;

    scr_bulb_tilemap_append_occluder_edges(_occluder, _tm, _occlude_mode);

    if (array_length(_occluder.vertexArray) <= 0) {
        _occluder.Destroy();
        _occluder.RemoveFromRenderer(_renderer);
        return undefined;
    }

    _occluder.__bboxXMin = 0;
    _occluder.__bboxYMin = 0;
    _occluder.__bboxXMax = room_width;
    _occluder.__bboxYMax = room_height;

    return _occluder;
}

/// @description Only lay_collision full blocks cast shadows. No near_tiles / platform occluders.
function scr_bulb_build_room_occluders(_renderer) {
    var _list = [];

    var _collision = scr_bulb_build_tilemap_occluders(_renderer, "lay_collision", "lay_collision");
    if (_collision != undefined) array_push(_list, _collision);

    if (array_length(_list) > 0) {
        _renderer.RefreshStaticOccluders();
    }

    return _list;
}

function scr_bulb_destroy_tilemap_occluders(_renderer, _occluder) {
    if (_occluder == undefined) return;

    _occluder.Destroy();
    if (_renderer != undefined) {
        _occluder.RemoveFromRenderer(_renderer);
    }
}

function scr_bulb_destroy_all_tilemap_occluders(_renderer, _occluder_list) {
    if (_occluder_list == undefined) return;

    for (var _i = 0; _i < array_length(_occluder_list); _i++) {
        scr_bulb_destroy_tilemap_occluders(_renderer, _occluder_list[_i]);
    }

    if (_renderer != undefined) {
        _renderer.RefreshStaticOccluders();
    }
}
