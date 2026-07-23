/// @function scr_hitstop_freeze_anims
/// @description Pause player/enemy sprite advances for the freeze window.
function scr_hitstop_freeze_anims() {
    with (obj_player) {
        if (instance_exists(id)) image_speed = 0;
    }
    with (obj_enemy) {
        if (instance_exists(id)) image_speed = 0;
    }
}

/// @function scr_hitstop_trigger
/// @description Queue global hitstop and freeze anims immediately on the impact frame.
/// @param {Real} _frames Freeze length in Steps (stacked via max).
function scr_hitstop_trigger(_frames) {
    if (_frames <= 0) return;
    global.hitstop = max(global.hitstop, _frames);
    scr_hitstop_freeze_anims();
}

/// @function scr_hitstop_handler
/// @description Call at the top of obj_player Step; returns true while frozen.
function scr_hitstop_handler() {
    if (global.hitstop > 0) {
        global.hitstop--;
        with (obj_player) scr_player_invincibility();
        scr_hitstop_freeze_anims();
        return true;
    }
    with (obj_player) {
        if (instance_exists(id)) {
            if (variable_instance_exists(id, "state") && state == PLAYER_STATE.PERFECT_DODGE_SLOWMO) {
                image_speed = scr_time_scale_get();
            } else {
                image_speed = 1;
            }
        }
    }
    // obj_enemy uses code-driven breath frames (scr_enemy_floating_hover), not image_speed
    return false;
}
