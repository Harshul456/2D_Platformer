/// Place at top-left of the scroll region. Set zone_w / zone_h (and default_zone) in Room Editor or Creation Code.
/// Optional per-zone airborne dead zone (MMX camera_vbor) — set zone_apply_vbor = true in Creation Code.
if (!variable_instance_exists(id, "zone_w")) zone_w = 640;
if (!variable_instance_exists(id, "zone_h")) zone_h = 360;
if (!variable_instance_exists(id, "default_zone")) default_zone = false;
if (!variable_instance_exists(id, "zone_apply_vbor")) zone_apply_vbor = false;
if (!variable_instance_exists(id, "zone_vbor_min_y")) zone_vbor_min_y = -48;
if (!variable_instance_exists(id, "zone_vbor_max_y")) zone_vbor_max_y = 48;

zone_min_x = x;
zone_min_y = y;
zone_max_x = x + zone_w;
zone_max_y = y + zone_h;
