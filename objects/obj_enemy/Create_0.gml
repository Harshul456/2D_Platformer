// @description obj_enemy create event

// Set the initial state using the global macro
state = STATE_IDLE;

obj_enemy_health = 100;
moveSpeed = 1;
chaseRange = 500;
attackRange = 30;

// For Knockback/stun
stunTimer = 0;
hit_blink_timer = 0;
knockbackX = 0;

// Physics
hsp = 0;
vsp = 0;
grv = 0.5;

// Remember the scale from the Room Editor
base_xscale = image_xscale; 
base_yscale = image_yscale;
knockback_pending_x = 0;
knockback_pending_y = 0;
knockback_pending_lift = false;