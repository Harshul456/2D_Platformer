// In Enemy Draw Event
// Force the enemy to snap to the pixel grid just like the player
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
                image_xscale, image_yscale, image_angle, image_blend, image_alpha);

// Debug Draw Collision Points
if (global.show_debug) {
    draw_set_color(c_red);
    var _side_dist = floor((bbox_right - bbox_left) * 0.5) - 1;
    var _waist_y = floor((bbox_top + bbox_bottom) * 0.5);
    draw_circle(floor(x) + _side_dist, _waist_y, 2, false); // Waist Right
    draw_circle(floor(x) - _side_dist, _waist_y, 2, false); // Waist Left
    draw_circle(floor(x), floor(bbox_bottom + 1), 2, false); // Floor check
    draw_set_color(c_white);
}