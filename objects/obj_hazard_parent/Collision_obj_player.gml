// Inside obj_hazard_parent -> Collision Event with obj_player
if (!other.is_dying) { // Only trigger if he isn't already in the death process
    other.is_dying = true;
    other.can_move = false;
    other.vsp = 2; // Optional: give him a tiny downward nudge to ensure he keeps falling
    other.alarm[0] = 60; // 60 frames = 1 second buffer (adjust as needed)
}