/// Subtle dim breathe — circle scale, Bulb intensity, and tile glow alpha share one phase.
if (bulb_light == undefined) exit;

glow_time += glow_breathe_speed;
var _t = (dsin(glow_time) + 1) * 0.5;
glow_pulse_t = _t;
glow_pulse_alpha = lerp(BULB_GLOW_PULSE_MIN, BULB_GLOW_PULSE_MAX, _t);

var _scale = lerp(glow_scale_tight, glow_scale_wide, _t);
bulb_light.xscale = glow_base_scale * _scale;
bulb_light.yscale = glow_base_scale * _scale;
bulb_light.intensity = glow_base_intensity * lerp(glow_intensity_tight, glow_intensity_wide, _t);
bulb_light.blend = glow_base_blend;

scr_crystal_spark_step(id);
