// --- obj_player Collision with obj_enemy (HK FSM — damage only during ATTACK sweep) ---
var _enemy_attack_active = (other.state == ENEMY_STATE.ATTACK && other.attack_frame > 0);
var _enemy_incapacitated = (other.state == ENEMY_STATE.STUNNED || other.stunTimer > 0
    || other.state == ENEMY_STATE.RECOIL || other.state == ENEMY_STATE.TELEGRAPH);

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

if (!invincible && _enemy_attack_active) {
    obj_player_health -= ENEMY_COLLISION_DAMAGE;
    attacking = false;
    attack_lockout = 0;
    attackCooldownTimer = 0;
    attack_buffer_timer = 0;
    attack_chain_buffer_timer = 0;
    attack_chain_latched = false;
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
    stunTimer = ENEMY_STUN_FRAMES;
    scr_camera_trigger_shake(4, 8);
    scr_hitstop_trigger(2);
    invincible = true;
    invincibleTimer = INVINCIBILITY_FRAMES;
}
