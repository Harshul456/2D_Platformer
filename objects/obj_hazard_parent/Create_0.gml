/// @description Hazard parent (pit, spikes, etc.) — collision with obj_player triggers death/reset.
// Tuning: death alarm and nudge so player doesn't clip into hazard
HAZARD_DEATH_ALARM    = 60;  // Frames before respawn (alarm[0] on player)
HAZARD_DEATH_VSP_NUDGE = 2;  // Downward nudge on death so player keeps falling
