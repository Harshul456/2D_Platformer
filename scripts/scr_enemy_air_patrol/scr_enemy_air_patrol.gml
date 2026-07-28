/// @file scr_enemy_air_patrol.gml
/// @description Lightweight aerial patrol / chase for floating enemies (no gravity).

/// @function scr_enemy_air_patrol_step
/// @description Horizontal float AI. Uses parent leash vars + moveSpeed / chaseRange when set.
function scr_enemy_air_patrol_step() {
    if (variable_global_exists("hitstop") && global.hitstop > 0) exit;
    if (!scr_time_scale_should_tick()) exit;

    // Hurt / death / attack handled by caller via gnd_state
    if (variable_instance_exists(id, "gnd_state")) {
        if (gnd_state == GND_STATE_DEAD) exit;
        if (gnd_state == GND_STATE_DAMAGED) {
            if (gnd_hurt_stun_timer > 0) {
                gnd_hurt_stun_timer--;
                hsp = gnd_knock_h;
                gnd_knock_h *= 0.88;
                x += hsp;
                // Soft wall stop
                if (scr_enemy_collision_tilemap() != noone) {
                    var _dir = sign(hsp);
                    if (_dir != 0 && check_tile_collision(x + _dir * 12, y - 24)) {
                        hsp = 0;
                        gnd_knock_h = 0;
                    }
                }
            }
            if (gnd_hurt_stun_timer <= 0) {
                gnd_state = GND_STATE_PATROL;
                hsp = 0;
                gnd_knock_h = 0;
            }
            exit;
        }
        // Charging / firing — hold position; combat script owns this state
        if (gnd_state == GND_STATE_ATTACK) {
            hsp = 0;
            vsp = 0;
            if (variable_instance_exists(id, "enemy_is_floating") && enemy_is_floating) {
                y = ystart;
                enemy_grounded = false;
            }
            exit;
        }
    }

    var _speed = (variable_instance_exists(id, "moveSpeed") ? moveSpeed : move_speed);
    var _chase_r = (variable_instance_exists(id, "chaseRange") ? chaseRange : sight_range);
    var _face = (variable_instance_exists(id, "gnd_facing") ? gnd_facing : 1);

    var _see_player = false;
    if (instance_exists(obj_player) && scr_enemy_player_is_valid_combat_target()) {
        var _dx = obj_player.x - x;
        var _dy = obj_player.y - y;
        // Air enemies engage in a tall vertical band (player on ground still counts)
        if (abs(_dx) <= _chase_r && abs(_dy) <= _chase_r * 0.85) {
            _see_player = true;
        }
    }

    if (_see_player) {
        gnd_state = GND_STATE_CHASE;
        var _dir = sign(obj_player.x - x);
        if (_dir == 0) _dir = _face;
        gnd_facing = _dir;
        image_xscale = abs(image_xscale) * _dir;
        // Ancient rock / hover-engage: lock in place and let the attack script charge
        if (variable_instance_exists(id, "air_hover_on_notice") && air_hover_on_notice) {
            hsp = 0;
        } else {
            hsp = _dir * _speed * 1.15;
        }
    } else {
        gnd_state = GND_STATE_PATROL;
        if (x <= gnd_patrol_x1) {
            gnd_facing = 1;
            image_xscale = abs(image_xscale);
        } else if (x >= gnd_patrol_x2) {
            gnd_facing = -1;
            image_xscale = -abs(image_xscale);
        }
        hsp = gnd_facing * _speed;
    }

    // Horizontal move with soft cave-wall probe (no gravity / floor)
    var _step = hsp;
    if (_step != 0) {
        var _try = x + _step;
        var _blocked = false;
        if (scr_enemy_collision_tilemap() != noone) {
            var _probe_x = (_step > 0) ? bbox_right + 2 : bbox_left - 2;
            var _mid_y = floor((bbox_top + bbox_bottom) * 0.5);
            _blocked = check_tile_collision(_probe_x, _mid_y)
                || check_tile_collision(_probe_x, bbox_top + 8)
                || check_tile_collision(_probe_x, bbox_bottom - 8);
        }
        if (_blocked) {
            hsp = 0;
            if (gnd_state == GND_STATE_PATROL) {
                gnd_facing *= -1;
                image_xscale = abs(image_xscale) * gnd_facing;
            }
        } else {
            x = _try;
        }
    }

    // Keep float anchor locked (hover draw offset provides bob)
    if (variable_instance_exists(id, "enemy_is_floating") && enemy_is_floating) {
        y = ystart;
        vsp = 0;
        enemy_grounded = false;
    }
}
