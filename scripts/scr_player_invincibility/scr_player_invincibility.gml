/// @function scr_player_dash_iframes_begin
/// @description Grant silent dodge i-frames at dash start (no alpha blink).
function scr_player_dash_iframes_begin() {
    var _frames = (variable_instance_exists(id, "DASH_IFRAME_FRAMES") ? DASH_IFRAME_FRAMES : 10);
    dash_iframe_timer = max(dash_iframe_timer, _frames);
}

/// @function scr_player_has_damage_iframes
/// @description True while hit invincibility or silent dash i-frames are active.
function scr_player_has_damage_iframes() {
    if (variable_instance_exists(id, "invincible") && invincible) return true;
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) return true;
    return false;
}

function scr_player_invincibility() {
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) {
        dash_iframe_timer--;
    }

    if (invincible) {
        invincibleTimer--;
        blinkCounter++;

        if (blinkCounter >= blinkDelay) {
            if (image_alpha == 1) {
                image_alpha = 0.5;
            } else {
                image_alpha = 1;
            }
            blinkCounter = 0;
        }

        if (invincibleTimer <= 0) {
            invincible = false;
            image_alpha = 1;
        }
    }
}
