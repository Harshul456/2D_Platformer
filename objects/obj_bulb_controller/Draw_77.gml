var _lit_scene = -1;

if (renderer != undefined) {
    var _emissive_overlays = BULB_GLOW_TILE_LAYER_ENABLED || BULB_CRYSTAL_SPARKS_ENABLED || BULB_ENEMY_GLOW_ENABLED;

    if (_emissive_overlays) {
        _lit_scene = scr_bulb_draw_lit_scene(renderer);
    } else {
        BulbDrawLitSurface(renderer, application_surface);
    }
}
scr_cave_dust_draw(id);
scr_ceiling_drip_draw(id);

// Low mist sits in front of parallax walls, behind player + emissive glow.
scr_cave_fog_draw(id);

scr_bulb_draw_glow_tile_layer();
scr_bulb_redraw_over_emissive_glow(_lit_scene);
scr_bulb_draw_enemy_emissive_glow_all();
scr_crystal_spark_draw_all();

scr_cave_vignette_draw();

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

if (bloom_hud_timer > 0) {
    var _cam2 = view_camera[0];
    if (instance_exists(obj_camera_controller)) _cam2 = obj_camera_controller.cam;

    var _vx2 = camera_get_view_x(_cam2);
    var _vy2 = camera_get_view_y(_cam2);
    var _bon = global.bulb_hdr_bloom_enabled;
    var _blabel = _bon ? "HDR bloom: ON" : "HDR bloom: OFF";

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(_bon ? c_aqua : c_yellow);
    draw_text(_vx2 + 8, _vy2 + 44, _blabel + "  (F9 toggle)");
    draw_set_color(c_white);
}
