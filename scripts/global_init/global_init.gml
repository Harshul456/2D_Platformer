/// @function global_init
/// @description Initializes all global variables and macros

// --- MACROS (States) ---
#macro STATE_IDLE 0
#macro STATE_CHASE 1
#macro STATE_ATTACK 2
#macro STATE_STUNNED 3

// --- GLOBAL VARIABLES ---
global.tilemap_collision_id = noone; 
global.player_id = noone;

// Force the game to render at your specific resolution without sub-pixel blurring
surface_resize(application_surface, 1280, 720); // Match your Viewport Width/Height
display_set_gui_size(1280, 720);

gpu_set_texfilter(false); // Disables "Interpolate Colors" (already done, but safe to force)
display_reset(0, true);   // Forces VSync ON via code

global.show_debug = false; // Renamed to avoid conflict with built-in variable
global.hitstop = 0;       // Hitstop frames (impact freeze); decremented in scr_hitstop_handler

// Toggle reflections on/off (for before/after captures)
global.reflections_enabled = true;

// Borderless fullscreen (more reliable)
window_set_fullscreen(true);

