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
    var _old_x = x;
    x += _push_away * COLLISION_SEPARATION_PUSH;
    // Don't push into tiles or pit – revert if we'd clip inside
    var _in_tile = (global.tilemap_collision_id != noone) && (
        check_tile_collision(bbox_left, bbox_top) || check_tile_collision(bbox_right, bbox_top) ||
        check_tile_collision(bbox_left, bbox_bottom) || check_tile_collision(bbox_right, bbox_bottom));
    var _in_hazard = place_meeting(x, y, obj_hazard_parent);
    if (_in_tile || _in_hazard) x = _old_x;
}

if (!invincible && !_protected) {
    obj_player_health -= ENEMY_COLLISION_DAMAGE;
    attacking = false;
    
    var _push_dir = sign(x - other.x);
    if (_push_dir == 0) _push_dir = -last_direction;
    
    knockBackX = _push_dir * ENEMY_KNOCKBACK_X;
    knockBackY = ENEMY_KNOCKBACK_Y;
    stunTimer = ENEMY_STUN_FRAMES;
    invincible = true;
    invincibleTimer = INVINCIBILITY_FRAMES;
}