// Room Start — drip tiles are scanned here, not only in rooms that have lighting.
if (!instance_exists(obj_bulb_controller)) {
    scr_ceiling_drip_init(id);
    scr_ceiling_drip_bake_emitters(id, BULB_CEILING_DRIP_LAYER);
}
