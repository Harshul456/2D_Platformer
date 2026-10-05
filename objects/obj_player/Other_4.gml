var _lay = layer_get_id("lay_collision");
global.tilemap_collision_id = layer_tilemap_get_id(_lay);
// Editor placement stays the fallback spawn. A door trip moves the player after this.
if (!scr_room_transition_apply_arrival()) {
    room_spawn_x = x;
    room_spawn_y = y;
}