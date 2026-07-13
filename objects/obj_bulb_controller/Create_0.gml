/// Bulb 2D lighting — dim cave ambient + dynamic lights (player, crystals, etc.)
var _cam = view_camera[0];
if (instance_exists(obj_camera_controller)) {
    _cam = obj_camera_controller.cam;
}

renderer = new BulbRenderer(_cam);
global.bulb_renderer = renderer;

renderer.ambientColor = make_colour_rgb(BULB_AMBIENT_R, BULB_AMBIENT_G, BULB_AMBIENT_B);
renderer.soft = false;
renderer.smooth = true;
renderer.exposure = BULB_HDR_EXPOSURE;

global.bulb_hdr_bloom_enabled = BULB_HDR_BLOOM_DEFAULT_ON;
renderer.hdr = global.bulb_hdr_bloom_enabled;
renderer.hdrBloomIntensity = global.bulb_hdr_bloom_enabled ? BULB_HDR_BLOOM_INTENSITY : 0;
renderer.hdrBloomIterations = BULB_HDR_BLOOM_ITERATIONS;
renderer.hdrBloomThresholdMin = BULB_HDR_BLOOM_THRESHOLD_MIN;
renderer.hdrBloomThresholdMax = BULB_HDR_BLOOM_THRESHOLD_MAX;

scr_bulb_set_normal_maps_enabled(BULB_NORMAL_MAPS_ENABLED);
normal_map_hud_timer = 0;
bloom_hud_timer = 0;

application_surface_draw_enable(false);

tilemap_occluders = [];
occluders_built = false;

lit_scene_surface = -1;

scr_cave_dust_init(id);
scr_ceiling_drip_init(id);
scr_cave_atmosphere_init(id);
