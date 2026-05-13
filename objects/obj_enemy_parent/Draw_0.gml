var _c = c_white;
if (variable_instance_exists(id, "gnd_state")) {
    if (gnd_state == 1) _c = merge_color(c_white, c_yellow, 0.22);
    else if (gnd_state == 2) _c = merge_color(c_white, c_orange, 0.4);
    else if (gnd_state == 3) _c = merge_color(c_white, c_aqua, 0.28);
}
image_blend = _c;
if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
    image_blend = merge_color(_c, c_red, 0.55);
}
draw_self();
image_blend = c_white;
