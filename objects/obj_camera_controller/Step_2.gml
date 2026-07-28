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
