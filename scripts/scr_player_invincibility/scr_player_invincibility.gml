function scr_player_invincibility(){
    if (invincible) {
        invincibleTimer--;
        blinkCounter++;
        
        if (blinkCounter >= blinkDelay) {
            if (image_alpha == 1) {
                image_alpha = 0.5;
            } else {
                image_alpha = 1;
            } // <--- Added this brace
            blinkCounter = 0;
        }
        
        if (invincibleTimer <= 0) {
            invincible = false;
            image_alpha = 1;
        }
    }
}