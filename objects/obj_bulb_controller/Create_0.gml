/// Bulb 2D lighting — dim cave ambient + dynamic lights (player, crystals, etc.)
var _cam = view_camera[0];
if (instance_exists(obj_camera_controller)) {
    _cam = obj_camera_controller.cam;
}

renderer = new BulbRenderer(_cam);
global.bulb_renderer = renderer;

renderer.ambientColor = make_colour_rgb(8, 10, 18);
renderer.soft = false;
renderer.smooth = true;
renderer.hdr = false;
renderer.exposure = 1.08;

scr_bulb_set_normal_maps_enabled(BULB_NORMAL_MAPS_ENABLED);
normal_map_hud_timer = 0;

application_surface_draw_enable(false);

tilemap_occluders = [];
occluders_built = false;
