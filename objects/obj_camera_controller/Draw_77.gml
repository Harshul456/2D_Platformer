/// Rooms without the lighting controller. Post-Draw lands on the back buffer, and the
/// health bar copies the room view afterwards — that copy was covering the hit sparks.
/// Paint the room here first, then the sparks, and let Draw GUI skip a second copy.
if (instance_exists(obj_bulb_controller)) exit;

global.room_view_presented = false;
if (surface_exists(application_surface)) {
    var _pos = application_get_position();
    var _old_filter = gpu_get_texfilter();
    var _old_blend = gpu_get_blendmode();
    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_normal);
    draw_surface_stretched(application_surface, _pos[0], _pos[1], _pos[2] - _pos[0], _pos[3] - _pos[1]);
    gpu_set_texfilter(_old_filter);
    gpu_set_blendmode(_old_blend);
    global.room_view_presented = true;
}

scr_ceiling_drip_draw(id);
scr_gameplay_fx_draw_world();
scr_gameplay_fx_draw_screen();
