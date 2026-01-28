function scr_enemy_movement() {
    // Derive sensors from current mask (supports 64x64 enemy now, future changes later)
    var _side = floor((bbox_right - bbox_left) * 0.5) - 4; // Padding from center
    var _waist_y = (bbox_top + bbox_bottom) * 0.5; // Waist height

    if (hsp != 0) {
        var _check_x = x + (_side * sign(hsp)) + hsp;

        // ONLY check the waist to prevent floor-snagging
        if (!check_tile_collision(_check_x, _waist_y)) {
            x += hsp;
        } else {
            hsp = 0; // Hit a real wall
        }
    }

    // Vertical Movement (Gravity)
    if (!check_tile_collision(x, y + vsp)) {
        y += vsp;
    } else {
        vsp = 0;
        y = round(y);
    }
}