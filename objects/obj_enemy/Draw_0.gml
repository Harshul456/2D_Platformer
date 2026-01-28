// In Enemy Draw Event
// Force the enemy to snap to the pixel grid just like the player
draw_sprite_ext(
    sprite_index,
    image_index,
    floor(x),
    floor(y),
    image_xscale,
    image_yscale,
    image_angle,
    image_blend,
    image_alpha
);


// Debug Draw Collision Points
draw_self();
draw_set_color(c_red);
var side_dist = 13;
draw_circle(round(x) + side_dist, round(y - 32), 2, false); // Waist Right
draw_circle(round(x) - side_dist, round(y - 32), 2, false); // Waist Left
draw_circle(round(x), round(y + 1), 2, false); // Floor check
draw_set_color(c_white);