// Begin Step — dash input + velocity/i-frames before other instances' Step (enemy attacks).
// Buffer Z during atk1 for poke→dash; startup lockout + buffer clear on attack start protect dash→attack.
if (stunTimer <= 0) {
    scr_player_input_poll();
    if (key_sprint_press) {
        dash_input_buffer = (variable_instance_exists(id, "DASH_INPUT_BUFFER_FRAMES") ? DASH_INPUT_BUFFER_FRAMES : 0);
    }
}
if (stunTimer <= 0 && global.hitstop <= 0) {
    scr_player_sprint_try_begin(true);
}
