function scr_player_attack() {
    if (!grounded) return;

    if (attacking) {
        if (image_index > image_number * 0.4) combo_buffer = true;
        return;
    }

    // Only valid mid-combo step is 1→2 (no third hit from buffer/timer).
    if (comboTimer > 0 && comboCount == 1) comboCount = 2;
    else comboCount = 1;

    attacking = true;
    combo_buffer = false;
    attack_chain_latched = false;
    attack_has_hit = false;
    image_index = 0;
    comboTimer = comboCooldown;

    switch (comboCount) {
        case 1:
            hsp = last_direction * 3;
            sprite_index = spr_asta_attack1;
            image_blend = c_white;
            break;
        case 2:
            hsp = last_direction * 3.5;
            sprite_index = spr_mc_attack2;
            image_blend = c_lime;
            break;
        case 3:
            hsp = last_direction * 5;
            sprite_index = spr_asta_attack1;
            image_blend = c_aqua;
            break;
    }
}