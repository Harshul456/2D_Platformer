if (renderer != undefined) {
    BulbDrawLitSurface(renderer, application_surface);
}

if (normal_map_hud_timer > 0) {
    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) _cam = obj_camera_controller.cam;

    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _on = global.bulb_normal_maps_enabled;
    var _label = _on ? "Normal maps: ON" : "Normal maps: OFF";

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(_on ? c_lime : c_yellow);
    draw_text(_vx + 8, _vy + 28, _label + "  (F8 toggle)");
    draw_set_color(c_white);
}
