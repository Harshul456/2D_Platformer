/// @description Return crystal light kind for a tile index, or -1 if not a crystal.
/// 0 = pink, 1 = purple, 2 = mixed (pink + purple in one tile)
function scr_bulb_crystal_kind_for_tile(_idx) {
    switch (_idx) {
        case 69:
        case 71:
        case 72:
            return 0;
        case 70:
            return 1;
        case 73:
            return 2;
    }
    return -1;
}

/// @description near_tiles rock-mass indices that cast shadows. Everything else (mushrooms, props, crystals) does not.
/// Add wall tile indices here when you paint new cave wall pieces.
function scr_bulb_near_tiles_casts_shadow(_idx) {
    if (scr_bulb_crystal_kind_for_tile(_idx) >= 0) return false;
    switch (_idx) {
        case 27:
        case 54:
        case 55:
        case 67:
        case 68:
            return true;
    }
    return false;
}

/// @description Spawn obj_bulb_crystal_light on crystal tiles in a tile layer.
/// @param {String} layer_name Tile layer to scan (default "near_tiles")
function scr_bulb_spawn_crystal_lights(_layer_name = "near_tiles") {
    if (!variable_global_exists("bulb_renderer") || global.bulb_renderer == undefined) return;

    var _layer = layer_get_id(_layer_name);
    if (_layer == -1) return;

    var _tm = layer_tilemap_get_id(_layer);
    if (_tm == -1) return;

    var _tw = tilemap_get_tile_width(_tm);
    var _th = tilemap_get_tile_height(_tm);
    var _w = tilemap_get_width(_tm);
    var _h = tilemap_get_height(_tm);
    var _ox = layer_get_x(_layer);
    var _oy = layer_get_y(_layer);

    for (var _cy = 0; _cy < _h; _cy++) {
        for (var _cx = 0; _cx < _w; _cx++) {
            var _idx = tile_get_index(tilemap_get(_tm, _cx, _cy));
            var _kind = scr_bulb_crystal_kind_for_tile(_idx);
            if (_kind < 0) continue;

            var _lx = _ox + _cx * _tw + _tw * 0.5;
            var _ly = _oy + _cy * _th + _th * 0.48;

            if (_kind == 2) {
                scr_bulb_crystal_light_create(_lx - 8, _ly, 0, 0.72);
                scr_bulb_crystal_light_create(_lx + 8, _ly, 1, 0.72);
            } else {
                scr_bulb_crystal_light_create(_lx, _ly, _kind, 1.0);
            }
        }
    }
}

/// @description Create one crystal light instance and apply its Bulb settings.
function scr_bulb_crystal_light_create(_x, _y, _kind, _scale_mul = 1.0) {
    var _inst = instance_create_layer(_x, _y, "Instances", obj_bulb_crystal_light);
    _inst.crystal_kind = _kind;
    scr_bulb_crystal_light_apply(_inst, _scale_mul);
}

/// @description Configure BulbLight color/size on a crystal light instance.
/// @param {Id.Instance} _inst obj_bulb_crystal_light instance
/// @param {Real} _scale_mul Optional scale multiplier (mixed tiles use smaller lights)
function scr_bulb_crystal_light_apply(_inst, _scale_mul = 1.0) {
    with (_inst) {
        if (bulb_light == undefined) return;

        switch (crystal_kind) {
            case 1: // purple
                bulb_light.intensity = 1.35;
                bulb_light.blend = make_colour_rgb(150, 90, 210);
                bulb_light.penumbraSize = 0;
                bulb_light.xscale = 1.35 * _scale_mul;
                bulb_light.yscale = 1.35 * _scale_mul;
                break;
            default: // pink
                bulb_light.intensity = 1.28;
                bulb_light.blend = make_colour_rgb(220, 115, 170);
                bulb_light.penumbraSize = 0;
                bulb_light.xscale = 1.28 * _scale_mul;
                bulb_light.yscale = 1.28 * _scale_mul;
                break;
        }

        bulb_light.castShadows = false;
        bulb_light.normalMap = true;
        bulb_light.normalMapZ = BULB_CRYSTAL_NORMAL_MAP_Z;

        scr_bulb_crystal_light_init_pulse(_inst);
    }
}

/// @description Subtle dim breathe — tiny scale/intensity wobble, color stays muted.
function scr_bulb_crystal_light_init_pulse(_inst) {
    with (_inst) {
        if (bulb_light == undefined) return;

        glow_base_intensity = bulb_light.intensity;
        glow_base_scale = bulb_light.xscale;
        glow_base_blend = bulb_light.blend;

        glow_time = random(360);
        glow_breathe_speed = 0.42 + random(0.18);

        glow_scale_tight = BULB_CRYSTAL_PULSE_SCALE_TIGHT;
        glow_scale_wide = BULB_CRYSTAL_PULSE_SCALE_WIDE;
        glow_intensity_tight = BULB_CRYSTAL_PULSE_INTENSITY_TIGHT;
        glow_intensity_wide = BULB_CRYSTAL_PULSE_INTENSITY_WIDE;

        glow_pulse_t = 0.5;
        glow_pulse_alpha = lerp(BULB_GLOW_PULSE_MIN, BULB_GLOW_PULSE_MAX, 0.5);

        scr_crystal_spark_init(_inst);
    }
}
