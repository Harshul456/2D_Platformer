scr_bulb_destroy_all_tilemap_occluders(renderer, tilemap_occluders);

tilemap_occluders = [];



if (renderer != undefined) {

    renderer = undefined;

}

global.bulb_renderer = undefined;

if (variable_instance_exists(id, "lit_scene_surface") && lit_scene_surface != -1 && surface_exists(lit_scene_surface)) {
    surface_free(lit_scene_surface);
}
lit_scene_surface = -1;

application_surface_draw_enable(true);

