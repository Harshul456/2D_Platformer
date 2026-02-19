// Inside obj_hazard_parent -> Collision Event with obj_player
if (!other.is_dying) {
    other.is_dying = true;
    other.can_move = false;
    other.vsp = HAZARD_DEATH_VSP_NUDGE;
    other.alarm[0] = HAZARD_DEATH_ALARM;
}