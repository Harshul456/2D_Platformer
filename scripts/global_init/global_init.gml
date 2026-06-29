/// @function global_init
/// @description Initializes all global variables and macros

// --- MACROS (States) ---
#macro STATE_IDLE 0
#macro STATE_CHASE 1
#macro STATE_ATTACK 2
#macro STATE_STUNNED 3
#macro STATE_AGGRESSIVE 4   // Post-hitstun: seeks swing; higher attack commitment than neutral chase
#macro STATE_PATIENT_WAIT 5       // Yellow "bait" hold, then wind-up attack
#macro STATE_DEFENSIVE_RETREAT 6 // Brief retreat to reset spacing
#macro STATE_THREAT_REACTION 7   // "Processing" frames before 25/45/30 roll
#macro STATE_THREAT_NEUTRAL 8   // Optional standoff before roll (neutral)
#macro STATE_PATROL 9          // Local leash walk when player not reachable / out of sight

// --- GLOBAL VARIABLES ---
global.tilemap_collision_id = noone; 
global.player_id = noone;
global.player_gamepad_slot = -1; // First connected pad for scr_player_input (-1 = none)
// One-way ledges (TileSet2 indices 1,5,34,35,36): bbox_bottom at start of Step; vsp after gravity (scr_player_movement sets each frame).
global.player_ledge_bb_prev = -1000000;
global.player_move_vsp = 0;

// Camera (MMX-style zones — obj_camera_zone + scr_camera_control)
global.camera_current_zone = -1;
global.camera_min_x = 0;
global.camera_min_y = 0;
global.camera_max_x = 0;
global.camera_max_y = 0;
global.camera_vbor_min_y = -48;  // Airborne: scroll up only if player is |min|+ px above view center
global.camera_vbor_max_y = 48;   // Airborne: scroll down only if this far below view center
global.camera_scroll_min_x = 5;  // Min horizontal view scroll speed (px/step)
global.camera_scroll_min_y = 3;  // Min vertical view scroll speed (px/step)

// Force the game to render at your specific resolution without sub-pixel blurring
surface_resize(application_surface, 1280, 720); // Match your Viewport Width/Height
display_set_gui_size(1280, 720);

gpu_set_texfilter(false); // Disables "Interpolate Colors" (already done, but safe to force)
display_reset(0, true);   // Forces VSync ON via code

global.show_debug = false; // Renamed to avoid conflict with built-in variable
global.hitstop = 0;       // Hitstop frames (impact freeze); decremented in scr_hitstop_handler

// Toggle reflections on/off (for before/after captures)
global.reflections_enabled = false;

// Bulb normal-map lighting (F8 toggles in-game via obj_bulb_controller)
global.bulb_normal_maps_enabled = BULB_NORMAL_MAPS_ENABLED;

// Borderless fullscreen (more reliable)
window_set_fullscreen(true);

