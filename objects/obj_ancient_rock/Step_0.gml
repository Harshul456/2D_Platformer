/// Aerial Step — overrides parent grounded FSM.

// Death flash → purple/grey shatter (ticks through hitstop, crystal-core style)
if (gnd_state == GND_STATE_DEAD) {
    if (!variable_instance_exists(id, "rock_death_started") || !rock_death_started) {
        rock_death_started = true;
        death_flash_timer = ENEMY_DEATH_FLASH_FRAMES;
        enemy_ai_enabled = false;
        hsp = 0;
        vsp = 0;
        image_blend = c_white;
        scr_hitstop_trigger(ENEMY_DEATH_HITSTOP);
        scr_camera_trigger_shake(ENEMY_DEATH_SHAKE_MAG, ENEMY_DEATH_SHAKE_DUR);
    }

    if (!variable_instance_exists(id, "death_flash_timer")) death_flash_timer = 0;
    death_flash_timer--;
    if (death_flash_timer <= 0) {
        scr_enemy_death_shatter();
        instance_destroy();
        exit;
    }

    scr_enemy_floating_hover_step();
    scr_enemy_crystal_light_step();
    x = round(x);
    y = round(ystart);
    exit;
}

if (global.hitstop > 0) {
    scr_enemy_floating_hover_step();
    scr_enemy_crystal_light_step();
    exit;
}

if (hit_blink_timer > 0) {
    hit_blink_timer--;
    if (hit_blink_timer % 4 == 0) {
        image_alpha = (image_alpha == 1) ? 0.45 : 1;
    }
} else {
    image_alpha = 1;
}

scr_enemy_air_patrol_step();
scr_enemy_floating_hover_step();
scr_enemy_crystal_light_step();
// After light pulse so charge brighten / flash sticks for this frame
scr_ancient_rock_attack_step();

x = round(x);
// y locked to ystart inside hover / air patrol — keep integer for pixel art
y = round(ystart);
