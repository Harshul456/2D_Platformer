if (keyboard_check_pressed(BULB_NORMAL_MAP_TOGGLE_KEY)) {
    scr_bulb_set_normal_maps_enabled(!global.bulb_normal_maps_enabled);
    normal_map_hud_timer = 180;
}

if (keyboard_check_pressed(BULB_HDR_BLOOM_TOGGLE_KEY)) {
    global.bulb_hdr_bloom_enabled = !global.bulb_hdr_bloom_enabled;
    if (renderer != undefined) {
        renderer.hdr = global.bulb_hdr_bloom_enabled;
        renderer.hdrBloomIntensity = global.bulb_hdr_bloom_enabled ? BULB_HDR_BLOOM_INTENSITY : 0;
    }
    bloom_hud_timer = 180;
}

if (normal_map_hud_timer > 0) normal_map_hud_timer--;
if (bloom_hud_timer > 0) bloom_hud_timer--;

scr_cave_dust_step(id);
scr_ceiling_drip_step(id);
scr_cave_fog_step(id);
scr_hit_distort_step();
