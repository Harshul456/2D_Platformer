/// @function scr_hitstop_handler
function scr_hitstop_handler() {
    if (global.hitstop > 0) {
        global.hitstop--;
        // Player Step is skipped during hitstop — still tick i-frames so dash hits aren't delayed until after freeze.
        with (obj_player) scr_player_invincibility();
        
        // Pause all animations
        with (obj_player) {
            image_speed = 0;
        }
        with (obj_enemy) {
            image_speed = 0;
        }
        
        // Optionally: Add screen shake here
        // camera_shake(2, 3);
        
        return true; // Indicates we're in hitstop
    } else {
        with (obj_player) image_speed = 1;
        // obj_enemy uses code-driven breath frames (scr_enemy_floating_hover), not image_speed
        return false;
    }
}