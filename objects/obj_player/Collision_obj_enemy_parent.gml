// --- obj_player Collision with obj_enemy_parent (grounded tilemap FSM) ---
var _st = variable_instance_exists(other, "gnd_state") ? other.gnd_state : -1;
var _enemy_incapacitated = (_st == GND_STATE_DAMAGED) || (_st == GND_STATE_DEAD);
var _attack_startup_prio = (attacking && attack_priority_timer > 0)
    || (attacking && image_index < ATTACK_HIT_ACTIVE_START_INDEX);
var _protected = (attack_recovery_grace > 0) || (attack_buffer_timer > 0) || _enemy_incapacitated
    || _attack_startup_prio;

if (place_meeting(x, y, other)) {
    var _push_away = sign(x - other.x);
    if (_push_away == 0) _push_away = -last_direction;
    var _old_x = x;
    x += _push_away * COLLISION_SEPARATION_PUSH;
    var _in_tile = (global.tilemap_collision_id != noone) && (
        check_tile_collision(bbox_left, bbox_top) || check_tile_collision(bbox_right, bbox_top) ||
        check_tile_collision(bbox_left, bbox_bottom) || check_tile_collision(bbox_right, bbox_bottom));
    var _in_hazard = place_meeting(x, y, obj_hazard_parent);
    if (_in_tile || _in_hazard) x = _old_x;
}

if (!invincible && !_protected) {
    var _dmg = ENEMY_COLLISION_DAMAGE;
    if (variable_instance_exists(other, "gnd_touch_damage")) _dmg = other.gnd_touch_damage;
    if (_st == GND_STATE_CHASE && variable_instance_exists(other, "gnd_touch_damage_chase")) {
        _dmg = other.gnd_touch_damage_chase;
    } else if (_st == GND_STATE_ATTACK && variable_instance_exists(other, "gnd_touch_damage_attack")) {
        _dmg = other.gnd_touch_damage_attack;
    } else if (_st == GND_STATE_PATROL && variable_instance_exists(other, "gnd_touch_damage_patrol")) {
        _dmg = other.gnd_touch_damage_patrol;
    }
    obj_player_health -= _dmg;
    attacking = false;
    attack_lockout = 0;
    attackCooldownTimer = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_shift_remaining = 0;
    combo_buffer = false;
    comboTimer = 0;
    comboCount = 0;
    debug_hitbox_active = false;
    attack_priority_timer = 0;
    
    var _push_dir = sign(x - other.x);
    if (_push_dir == 0) _push_dir = -last_direction;
    
    knockBackX = _push_dir * ENEMY_KNOCKBACK_X;
    knockBackY = ENEMY_KNOCKBACK_Y;
    if (variable_instance_exists(other, "gnd_touch_knock_x")) knockBackX = _push_dir * other.gnd_touch_knock_x;
    if (variable_instance_exists(other, "gnd_touch_knock_y")) knockBackY = other.gnd_touch_knock_y;
    stunTimer = ENEMY_STUN_FRAMES;
    if (variable_instance_exists(other, "gnd_touch_stun_frames") && other.gnd_touch_stun_frames > 0) {
        stunTimer = other.gnd_touch_stun_frames;
    }
    invincible = true;
    invincibleTimer = INVINCIBILITY_FRAMES;
}
