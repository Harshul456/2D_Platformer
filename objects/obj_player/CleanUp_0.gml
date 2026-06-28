// Shader-based reflection doesn't require surface cleanup
if (variable_instance_exists(id, "bulb_light") && bulb_light != undefined) {
    bulb_light.Destroy();
    bulb_light = undefined;
}