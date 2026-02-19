/// @function scr_hitstop_handler
function scr_hitstop_handler() {
    if (global.hitstop > 0) {
        global.hitstop--;
        
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
        with (obj_enemy) image_speed = 1;
        return false;
    }
}