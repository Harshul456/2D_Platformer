life--;
var _u = 1 - (life / max(1, life_max));
image_xscale = lerp(0.55, 2.4, _u);
image_yscale = image_xscale;
if (life <= 0) instance_destroy();
