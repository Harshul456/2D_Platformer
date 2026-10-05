/// Draw GUI — screen-space HUD (health bar, etc.)
// The camera Post-Draw already placed the room and the hit sparks. Copying the
// room again here would paint over those sparks. If that pass did not run, copy it now.
var _already = variable_global_exists("room_view_presented") && global.room_view_presented;
if (!_already && variable_global_exists("present_room_in_gui") && global.present_room_in_gui
    && surface_exists(application_surface)) {
    var _gui_w = display_get_gui_width();
    var _gui_h = display_get_gui_height();
    draw_surface_stretched(application_surface, 0, 0, _gui_w, _gui_h);
}
if (variable_global_exists("room_view_presented")) global.room_view_presented = false;
scr_player_hud_draw();
