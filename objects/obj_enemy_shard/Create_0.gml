/// Flying geometric crystal shard from a shattered enemy.
image_speed = 0;
// Bulb rooms draw this in Post-Draw so fog cannot bury it. Without that controller, draw normally.
visible = !instance_exists(obj_bulb_controller);

size = random_range(2, 5);
shard_color = choose(c_aqua, c_white, c_orange); // Overridden by shatter to match enemy palette

// High-velocity explosive trajectory (built-in speed/direction/gravity move the instance)
direction = random(360);
speed = random_range(4, 9);
gravity_direction = 270;   // Down
gravity = 0.35;            // Shards arc downward naturally

angle = random(360);       // Spin orientation
spin = random_range(-16, 16);

life = random_range(40, 60);
life_max = life;
