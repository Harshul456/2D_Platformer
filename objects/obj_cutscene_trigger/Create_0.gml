/// Placeable one-shot cutscene trigger. Configure look target in RoomCreationCode or Creation Code.
/// Defaults: camera scout to (look_x, look_y) when player enters the rect.
/// Set cutscene_id (string) so it only plays once per session for that room beat.

if (!variable_instance_exists(id, "look_x")) look_x = x;
if (!variable_instance_exists(id, "look_y")) look_y = y;
if (!variable_instance_exists(id, "one_shot")) one_shot = true;
if (!variable_instance_exists(id, "triggered")) triggered = false;
if (!variable_instance_exists(id, "trigger_w")) trigger_w = 96;
if (!variable_instance_exists(id, "trigger_h")) trigger_h = 128;
if (!variable_instance_exists(id, "pan_frames")) pan_frames = 70;
if (!variable_instance_exists(id, "hold_frames")) hold_frames = 40;
if (!variable_instance_exists(id, "cutscene_id")) cutscene_id = "";
// Cutscene kind — currently only CAMERA_SCOUT; extend via Creation Code later.
if (!variable_instance_exists(id, "cutscene_kind")) cutscene_kind = CUTSCENE_KIND.CAMERA_SCOUT;

trigger_min_x = x - trigger_w * 0.5;
trigger_min_y = y - trigger_h * 0.5;
trigger_max_x = x + trigger_w * 0.5;
trigger_max_y = y + trigger_h * 0.5;

// Already seen this beat (room reload / death restart) — stay consumed
if (one_shot && scr_cutscene_was_played(cutscene_id)) {
    triggered = true;
}
