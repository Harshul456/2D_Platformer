/// @description Turn Bulb normal-map lighting on or off (renderer + all dynamic lights).
/// @param {Bool} _enabled
function scr_bulb_set_normal_maps_enabled(_enabled) {
    global.bulb_normal_maps_enabled = _enabled;

    if (!variable_global_exists("bulb_renderer") || global.bulb_renderer == undefined) return;

    global.bulb_renderer.normalMap = _enabled;

    with (obj_bulb_crystal_light) {
        if (bulb_light != undefined) bulb_light.normalMap = _enabled;
    }

    with (obj_enemy) {
        if (variable_instance_exists(id, "bulb_light") && bulb_light != undefined) {
            bulb_light.normalMap = _enabled;
        }
    }

    with (obj_player) {
        if (bulb_light != undefined) bulb_light.normalMap = _enabled;
    }
}
