/// Subtle dim breathe — small scale wobble, no bright color shift.
if (bulb_light == undefined) exit;

glow_time += glow_breathe_speed;
var _t = (dsin(glow_time) + 1) * 0.5;

var _scale = lerp(glow_scale_tight, glow_scale_wide, _t);
bulb_light.xscale = glow_base_scale * _scale;
bulb_light.yscale = glow_base_scale * _scale;
bulb_light.intensity = glow_base_intensity * lerp(glow_intensity_tight, glow_intensity_wide, _t);
bulb_light.blend = glow_base_blend;
