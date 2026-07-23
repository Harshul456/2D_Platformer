/// @function scr_player_dash_iframes_begin
/// @description Grant silent dodge i-frames at dash start (no alpha blink).
function scr_player_dash_iframes_begin() {
    var _frames = (variable_instance_exists(id, "DASH_IFRAME_FRAMES") ? DASH_IFRAME_FRAMES : 10);
    dash_iframe_timer = max(dash_iframe_timer, _frames);
    if (variable_instance_exists(id, "perfect_dodge_used")) perfect_dodge_used = false;
}

/// @function scr_player_has_damage_iframes
/// @description True while hit invincibility, silent dash i-frames, or death sequence are active.
function scr_player_has_damage_iframes() {
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.DEATH) return true;
    // Fade respawn: ALIVE under black/fade — still block hits until control unlocks (no spawn blink).
    if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
        && variable_instance_exists(id, "death_fade_phase")
        && death_fade_phase != DEATH_SEQ.NONE) {
        return true;
    }
    if (variable_instance_exists(id, "invincible") && invincible) return true;
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) return true;
    return false;
}

function scr_player_invincibility() {
    if (variable_instance_exists(id, "dash_iframe_timer") && dash_iframe_timer > 0) {
        dash_iframe_timer--;
    }

    // Death sequence owns visibility — never blink the hurt/dissolve body.
    if (variable_instance_exists(id, "state") && state == PLAYER_STATE.DEATH) {
        return;
    }
    if (variable_instance_exists(id, "death_is_dissolve") && death_is_dissolve
        && variable_instance_exists(id, "death_fade_phase")
        && death_fade_phase != DEATH_SEQ.NONE) {
        return;
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
