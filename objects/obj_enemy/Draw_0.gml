scr_enemy_draw_main_sprite();

// Debug Draw Collision Points
if (global.show_debug) {
    draw_set_color(c_red);
    var _side_dist = floor((bbox_right - bbox_left) * 0.5) - 1;
    var _waist_y = floor((bbox_top + bbox_bottom) * 0.5);
    draw_circle(floor(x) + _side_dist, _waist_y, 2, false);
    draw_circle(floor(x) - _side_dist, _waist_y, 2, false);
    draw_circle(floor(x), floor(bbox_bottom + 1), 2, false);
    draw_set_color(c_white);
}
