// Full room height, wide enough that a dash cannot step over the column.
var _half = 16;
var _hit = collision_rectangle(x - _half, 0, x + _half, room_height, obj_player, false, true);
if (_hit != noone) scr_checkpoint_activate(id);
