function scr_player_attack() {
    if (!grounded) return;

    if (attacking) {
        if (image_index > image_number * 0.4) combo_buffer = true;
        return;
    }

    if (comboTimer > 0) comboCount = (comboCount % 3) + 1;
    else comboCount = 1;

    attacking = true;
    combo_buffer = false;
    attack_has_hit = false;
    image_index = 0;
    comboTimer = comboCooldown;

    // Apply the burst. We use higher numbers because we'll be 
    // applying friction in the Step Event to slow it down quickly.
    switch (comboCount) {
        case 1: hsp = last_direction * 4; sprite_index = spr_asta_attack1; image_blend = c_white; break;
        case 2: hsp = last_direction * 5; sprite_index = spr_asta_attack1; image_blend = c_lime;  break;
        case 3: hsp = last_direction * 8; sprite_index = spr_asta_attack1; image_blend = c_aqua;  break;
    }
}