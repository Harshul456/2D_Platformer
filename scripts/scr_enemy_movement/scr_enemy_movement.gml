function scr_enemy_movement() {
    var _side = 28; // Padding from center
    var _waist_y = y - 32; // Check 1 tile up from floor

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