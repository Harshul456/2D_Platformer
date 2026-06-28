/// Invisible crystal light — pink (0) or purple (1). Auto-spawned from near_tiles or placed manually.
if (!variable_global_exists("bulb_renderer") || global.bulb_renderer == undefined) {
    instance_destroy();
    exit;
}

if (!variable_instance_exists(id, "crystal_kind")) {
    crystal_kind = 0;
}

bulb_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
scr_bulb_crystal_light_apply(id);
