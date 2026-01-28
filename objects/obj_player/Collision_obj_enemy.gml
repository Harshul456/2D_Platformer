// --- obj_player Collision Event with obj_enemy ---
var _is_swinging = (attacking); 
var _facing_enemy = (other.x > x && last_direction == 1) || (other.x < x && last_direction == -1);
var _enemy_incapacitated = (other.state == STATE_STUNNED || other.stunTimer > 0);
var _protected = (_is_swinging && _facing_enemy) || _enemy_incapacitated;

// NEW: SEPARATION LOGIC
// If we are overlapping (even if protected), push the player out 
// so we don't end the animation inside the enemy's hitbox.
if (place_meeting(x, y, other)) {
    var _push_away = sign(x - other.x);
    if (_push_away == 0) _push_away = -last_direction;
    x += _push_away * 1.5; // Soft push-back
}

if (!invincible && !_protected) {
    obj_player_health -= 10;
    attacking = false;
    
    var _push_dir = sign(x - other.x);
    if (_push_dir == 0) _push_dir = -last_direction;
    
    knockBackX = _push_dir * 4;
    knockBackY = -3;
    stunTimer = 15;
    invincible = true;
    invincibleTimer = 90;
}