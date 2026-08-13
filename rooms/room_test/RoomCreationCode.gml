global_init();

// --- Camera zones ---
// Default: full-room scroll bounds, normal look-ahead.
// Run-jump cue + landing restore are look-ahead-only (do not clamp scroll to their rects).

with (obj_camera_zone) {
    // Editor marker at 64,128 — full-room default scroll box.
    if (abs(x - 64) < 1 && abs(y - 128) < 1) {
        zone_w = room_width;
        zone_h = room_height;
        default_zone = true;
        zone_apply_bounds = true;
        zone_look_ahead_mult = 1;
        zone_look_ahead_bonus = 0;
        zone_look_ahead_trail_margin = 0.16; // normal framing
        zone_priority = 0;
        zone_min_x = 0;
        zone_min_y = 0;
        zone_max_x = room_width;
        zone_max_y = room_height;
    }

    // Approach / run-jump ONLY: more ahead, player sits nearer the trailing edge but stays on-screen.
    if (abs(x - 1792) < 1 && abs(y - 608) < 1) {
        zone_w = 720;
        zone_h = 420;
        default_zone = false;
        zone_apply_bounds = false; // keep full-room scroll
        zone_look_ahead_mult = 1.75;
        zone_look_ahead_bonus = 90;
        zone_look_ahead_trail_margin = 0.10; // allow ~256px look @ 640 view
        zone_priority = 10;
        // Extend upward so standing on the approach platform still counts as "inside".
        zone_min_x = x - 64;
        zone_min_y = y - 192;
        zone_max_x = zone_min_x + zone_w;
        zone_max_y = zone_min_y + zone_h;
    }

    // Landing platform: restore normal framing.
    if (abs(x - 2432) < 1 && abs(y - 672) < 1) {
        zone_w = 520;
        zone_h = 360;
        default_zone = false;
        zone_apply_bounds = false;
        zone_look_ahead_mult = 1;
        zone_look_ahead_bonus = 0;
        zone_look_ahead_trail_margin = 0.16;
        zone_priority = 10;
        zone_min_x = x - 32;
        zone_min_y = y - 160;
        zone_max_x = zone_min_x + zone_w;
        zone_max_y = zone_min_y + zone_h;
    }
}

// --- Cutscene: run-jump scout (disabled for now — re-enable later) ---
// Logic lives in scr_cutscene + obj_cutscene_trigger. Example placement:
//   instance_create_layer(1504, 768, "Instances", obj_cutscene_trigger);
//   then set cutscene_id / look_x / look_y / trigger bounds on that instance.
/*
var _cut_layer = layer_get_id("Instances");
if (_cut_layer == -1) _cut_layer = layer_get_id("Compatibility_Instances_Depth_0");
var _has_scout = false;
with (obj_cutscene_trigger) {
    if (abs(x - 1504) < 1 && abs(y - 768) < 1) _has_scout = true;
}
if (!_has_scout && _cut_layer != -1) {
    instance_create_layer(1504, 768, _cut_layer, obj_cutscene_trigger);
}

with (obj_cutscene_trigger) {
    if (abs(x - 1504) < 1 && abs(y - 768) < 1) {
        cutscene_id = "room_test_runjump_scout_v2";
        look_x = 2432;
        look_y = 768;
        one_shot = true;
        trigger_w = 96;
        trigger_h = 192;
        pan_frames = 130;
        hold_frames = 45;
        cutscene_kind = CUTSCENE_KIND.CAMERA_SCOUT;
        trigger_min_x = x - trigger_w * 0.5;
        trigger_max_x = x + trigger_w * 0.5;
        trigger_max_y = y + 64;
        trigger_min_y = trigger_max_y - trigger_h;
        if (scr_cutscene_was_played(cutscene_id)) triggered = true;
    }
}
*/

audio_play_sound(s_cave_placeholder, 1, true);
