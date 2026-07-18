life--;
if (life <= 0) {
    instance_destroy();
    exit;
}

angle += spin;

// Bounce off solid floor/walls using the tile collision map (no obj_wall instances).
var _tm = (variable_global_exists("tilemap_collision_id") ? global.tilemap_collision_id : noone);
if (_tm != noone && _tm != -1) {
    // Floor: reflect vertical velocity when moving down into a solid tile.
    if (vspeed > 0 && tilemap_point_solid(_tm, x, y + vspeed + 1)) {
        vspeed = -vspeed * 0.4;
        hspeed *= 0.6;
        spin *= 0.6;
        if (abs(vspeed) < 0.6) vspeed = 0;
    }
    // Wall: reflect horizontal velocity into a solid tile.
    if (hspeed != 0 && tilemap_point_solid(_tm, x + hspeed, y)) {
        hspeed = -hspeed * 0.4;
    }
}
