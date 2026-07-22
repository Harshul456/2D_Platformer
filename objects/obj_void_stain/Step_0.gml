life--;
if (life <= 0) {
    instance_destroy();
    exit;
}
image_alpha = (life / life_max) * 0.85;
