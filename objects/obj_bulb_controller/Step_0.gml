if (keyboard_check_pressed(BULB_NORMAL_MAP_TOGGLE_KEY)) {
    scr_bulb_set_normal_maps_enabled(!global.bulb_normal_maps_enabled);
    normal_map_hud_timer = 180;
}

if (normal_map_hud_timer > 0) normal_map_hud_timer--;

scr_cave_dust_step(id);
scr_ceiling_drip_step(id);
scr_cave_fog_step(id);
