// Lighting rooms already step drips on obj_bulb_controller. Everywhere else the
// ceiling tile layer still rains, as long as this camera is in the room.
if (!instance_exists(obj_bulb_controller)) {
    scr_ceiling_drip_step(id);
}

if (scr_cutscene_active()) {
    scr_cutscene_step();
} else {
    scr_cutscene_poll_triggers();
    if (scr_cutscene_active()) {
        scr_cutscene_step();
    } else {
        scr_camera_control();
    }
}
