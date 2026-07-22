/// Pixel debris from player void-dissolve death — dark grey / purple cave palette.
image_speed = 0;
visible = false; // Drawn in Bulb Post-Draw so fog/glow cannot bury it

speed = random_range(1, 4);
direction = random(360);
gravity_direction = 270;
gravity = 0.15;
friction = 0.08;

life_max = random_range(30, 50);
life = life_max;
image_alpha = 1;

size = irandom_range(1, 3);

// Suit + cave-floor tones (matches ground debris palette)
var _palette = [
    make_color_rgb(46, 36, 51),    // #2E2433 ground shadow
    make_color_rgb(74, 59, 82),    // #4A3B52 ground base
    make_color_rgb(94, 74, 102),   // #5E4A66 ground mid
    make_color_rgb(58, 42, 72),    // deep suit purple
    make_color_rgb(28, 22, 34),    // near-void black
    make_color_rgb(110, 78, 128)   // muted crystal purple
];
col = _palette[irandom(array_length(_palette) - 1)];
glow_col = make_color_rgb(72, 48, 96); // soft void halo
