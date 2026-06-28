scr_camera_control();

// Dash screen-shader intensity decay (pipeline reads global.dash_shader_active / intensity)
if (global.dash_shader_active) {
    global.dash_shader_intensity -= global.dash_shader_decay_per_frame;
    if (global.dash_shader_intensity <= 0) {
        global.dash_shader_intensity = 0;
        global.dash_shader_active = false;
    }
}