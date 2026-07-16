// --- obj_player Collision with obj_enemy (HK FSM — slash hitbox only during ATTACK) ---
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

// Backup slash check if Step order missed overlap this frame (scr_enemy_apply_attack_hit dedupes).
if (!scr_player_has_damage_iframes() && other.state == ENEMY_STATE.ATTACK && !other.attack_hit_dealt) {
    with (other) {
        scr_enemy_apply_attack_hit();
    }
}
