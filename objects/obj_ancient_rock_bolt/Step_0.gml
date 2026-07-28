/// Aimed bolt — locks direction at fire, then flies straight into tiles / player.
if (variable_global_exists("hitstop") && global.hitstop > 0) exit;
if (!scr_time_scale_should_tick()) exit;

life -= 1;
if (life <= 0) {
    instance_destroy();
    exit;
}

speed = 0;
hspeed = 0;
vspeed = 0;

// No mid-flight tracking — direction locked at spawn
bolt_spd = ROCK_BOLT_SPEED;
scr_ancient_rock_bolt_anim_step();

var _nx = x + lengthdir_x(bolt_spd, bolt_dir);
var _ny = y + lengthdir_y(bolt_spd, bolt_dir);

// Die on wall / floor tiles (probe a few points so thin hits still count)
var _tm = (variable_global_exists("tilemap_collision_id") ? global.tilemap_collision_id : noone);
var _hit_tile = false;
if (_tm != noone && _tm != -1) {
    _hit_tile = tilemap_point_solid(_tm, _nx, _ny)
        || tilemap_point_solid(_tm, _nx + 3, _ny)
        || tilemap_point_solid(_tm, _nx - 3, _ny)
        || tilemap_point_solid(_tm, _nx, _ny + 3)
        || tilemap_point_solid(_tm, _nx, _ny - 3);
} else if (check_tile_collision(_nx, _ny)) {
    _hit_tile = true;
}

if (_hit_tile) {
    repeat (4) {
        var _p = instance_create_layer(x, y, scr_hit_fx_layer(), obj_hit_particle);
        with (_p) {
            direction = random(360);
            speed = random_range(1.2, 3.2);
            col = c_white;
            glow_col = BULB_ANCIENT_ROCK_LIGHT_BLEND;
            size = irandom_range(1, 3);
            life_max = irandom_range(6, 12);
            life = life_max;
        }
    }
    instance_destroy();
    exit;
}

x = _nx;
y = _ny;

// Push trail sample after move
if (variable_instance_exists(id, "bolt_trail")) {
    array_insert(bolt_trail, 0, { x: x, y: y, life: 10 });
    while (array_length(bolt_trail) > 12) {
        array_delete(bolt_trail, array_length(bolt_trail) - 1, 1);
    }
}

if (bulb_light != undefined) {
    bulb_light.x = x;
    bulb_light.y = y;
    // Breathe intensity with the visual pulse
    var _pulse = 0.5 + 0.5 * dsin(bolt_pulse_t);
    bulb_light.intensity = lerp(0.75, 1.25, _pulse);
    var _sc = ROCK_BOLT_LIGHT_SCALE * lerp(0.9, 1.15, _pulse);
    bulb_light.xscale = _sc;
    bulb_light.yscale = _sc;
}

// Damage player on overlap
if (!hit_dealt && instance_exists(obj_player)) {
    if (collision_circle(x, y, ROCK_BOLT_RADIUS + 2, obj_player, false, true) != noone) {
        var _dodged = false;
        with (obj_player) {
            _dodged = scr_player_has_damage_iframes();
        }
        if (!_dodged) {
            hit_dealt = true;
            var _hx = x;
            var _hy = y;
            with (obj_player) {
                obj_player_health -= other.damage;
                var _push_dir = sign(x - other.x);
                if (_push_dir == 0) _push_dir = -last_direction;
                knockBackX = _push_dir * ROCK_BOLT_KNOCK_X;
                knockBackY = ROCK_BOLT_KNOCK_Y;
                if (grounded) knockBackY = 0;
                stunTimer = ENEMY_STUN_FRAMES;
                hurt_is_air = !grounded;
                hurt_air_landed = false;
                hurt_anim_tick = 0;
                attacking = false;
                attack_lockout = 0;
                attack_commit_lock = 0;
                attack_recovery_lock = 0;
                attackCooldownTimer = 0;
                attack_buffer_timer = 0;
                attack_chain_buffer_timer = 0;
                attack_chain_latched = false;
                attack_shift_remaining = 0;
                combo_buffer = false;
                comboTimer = 0;
                comboCount = 0;
                debug_hitbox_active = false;
                is_sprinting = false;
                sprint_afterimage_tick = 0;
                sprint_jump_carry = false;
                sprint_air_trail = false;
                invincible = true;
                invincibleTimer = INVINCIBILITY_FRAMES;
                attack_priority_timer = 0;
                _hx = lerp(other.x, x, 0.55);
                _hy = lerp(other.y, (bbox_top + bbox_bottom) * 0.5, 0.55);
            }
            // Same slash + debris burst as striking an enemy
            scr_hit_slash_create(_hx, _hy, bolt_dir, 78, c_aqua, 7, true, false);
            var _ang2 = bolt_dir + random_range(-16, 16);
            scr_hit_slash_create(
                _hx + lengthdir_x(3, _ang2 + 90),
                _hy + lengthdir_y(3, _ang2 + 90),
                _ang2,
                78 * 0.68,
                c_aqua,
                5,
                false,
                false
            );
            scr_camera_trigger_shake(2.2, 10);
            scr_hitstop_trigger(4);
            instance_destroy();
            exit;
        }
    }
}
