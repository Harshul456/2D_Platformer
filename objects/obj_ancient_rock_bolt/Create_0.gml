/// Aimed crystal bolt — animated body, trail, sparks. Drawn in Bulb post-draw.
visible = false;

owner = noone;
damage = ROCK_BOLT_DAMAGE;
life = ROCK_BOLT_LIFE;
hit_dealt = false;

bolt_dir = 0;
bolt_spd = ROCK_BOLT_SPEED;
// Disable built-in motion — we step manually so tile probes stay accurate
speed = 0;
hspeed = 0;
vspeed = 0;

// --- Visual animation ---
bolt_spin = random(360);
bolt_spin_spd = random_range(9, 14);
bolt_pulse_t = random(360);
bolt_flicker = random(100);
bolt_age = 0;
bolt_trail = [];      // recent positions for ribbon trail
bolt_sparks = [];     // orbiting / shed sparkles
bolt_spark_accum = 0;

bulb_light = undefined;
if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
    bulb_light = new BulbLight(global.bulb_renderer, sLight128, 0, x, y);
    bulb_light.intensity = 0.95;
    bulb_light.blend = BULB_ANCIENT_ROCK_LIGHT_BLEND;
    bulb_light.penumbraSize = 0;
    bulb_light.xscale = ROCK_BOLT_LIGHT_SCALE;
    bulb_light.yscale = ROCK_BOLT_LIGHT_SCALE;
    bulb_light.castShadows = false;
    bulb_light.normalMap = variable_global_exists("bulb_normal_maps_enabled")
        ? global.bulb_normal_maps_enabled
        : false;
}
