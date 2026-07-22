/// Dark void ink left on the cave floor where the player dissolved.
visible = false; // Drawn in Bulb Post-Draw
image_speed = 0;

life_max = 90;
life = life_max;
image_alpha = 0.85;

stain_w = random_range(14, 22);
stain_h = random_range(4, 7);
col = make_color_rgb(22, 16, 28);
glow_col = make_color_rgb(48, 32, 64);
