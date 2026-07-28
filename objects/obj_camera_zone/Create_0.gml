/// Place at top-left of the region. Configure in Room Editor Creation Code or RoomCreationCode.
/// Optional per-zone airborne dead zone (MMX camera_vbor) — set zone_apply_vbor = true.
/// Look-ahead: zone_look_ahead_mult / zone_look_ahead_bonus (bonus is px added in facing dir).
/// Set zone_apply_bounds = false for look-ahead-only cue zones (keeps room scroll box).
if (!variable_instance_exists(id, "zone_w")) zone_w = 640;
if (!variable_instance_exists(id, "zone_h")) zone_h = 360;
if (!variable_instance_exists(id, "default_zone")) default_zone = false;
if (!variable_instance_exists(id, "zone_apply_vbor")) zone_apply_vbor = false;
if (!variable_instance_exists(id, "zone_vbor_min_y")) zone_vbor_min_y = -48;
if (!variable_instance_exists(id, "zone_vbor_max_y")) zone_vbor_max_y = 48;
if (!variable_instance_exists(id, "zone_apply_bounds")) zone_apply_bounds = true;
if (!variable_instance_exists(id, "zone_look_ahead_mult")) zone_look_ahead_mult = 1;
if (!variable_instance_exists(id, "zone_look_ahead_bonus")) zone_look_ahead_bonus = 0;
// Min fraction of view width the player must keep from the trailing edge (lower = more look-ahead).
if (!variable_instance_exists(id, "zone_look_ahead_trail_margin")) zone_look_ahead_trail_margin = 0.16;
if (!variable_instance_exists(id, "zone_priority")) zone_priority = 0; // higher wins when overlapping

zone_min_x = x;
zone_min_y = y;
zone_max_x = x + zone_w;
zone_max_y = y + zone_h;
