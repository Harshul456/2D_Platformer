function scr_enemy_ai(){
    if (!instance_exists(obj_player)) {
        hsp = 0;
        return;
    }

    // 1. CALCULATE DISTANCES
    // Since both use a 64px static mask, _dist_x is the center-to-center distance.
    var _dist_x = abs(obj_player.x - x); 
    var _dist_total = point_distance(x, y, obj_player.x, obj_player.y);
    var _dir = sign(obj_player.x - x);

    switch(state) {
        case STATE_IDLE:
            hsp = 0;
            // Transition to chase if player is within range
            if (_dist_total < chaseRange) {
                state = STATE_CHASE;
            }
            break;

        case STATE_CHASE:
            // 2. MOVEMENT LOGIC
            // Stop distance adapts to mask sizes (supports 64x64 now, future larger masks later)
            var _enemy_half_w  = (bbox_right - bbox_left) * 0.5;
            var _player_half_w = (obj_player.bbox_right - obj_player.bbox_left) * 0.5;
            // Small inset so they don't overlap due to rounding/lerps
            var _stop_distance = max((_enemy_half_w + _player_half_w) - 4, 0);

            if (_dist_x > _stop_distance) {
                hsp = _dir * moveSpeed; 
            } else {
                hsp = 0; // Close enough!
            }
            
            // 3. VISUALS
            if (_dir != 0) image_xscale = base_xscale * _dir;

            // 4. TRANSITION BACK TO IDLE
            // We use a "buffer" (1.2x range) so the enemy doesn't snap 
            // back and forth at the edge of the chase circle.
            if (_dist_total > chaseRange * 1.2) {
                state = STATE_IDLE;
                hsp = 0;
            }
            break;
    }

    // 5. DEBUG OUTPUT
    if (global.show_debug && state == STATE_CHASE) {
        show_debug_message("Dist_X: " + string(_dist_x) + " | HSP: " + string(hsp) + " | Dir: " + string(_dir));
    }
}