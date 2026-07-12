/// @description obj_enemy body + crystal tint/rim (no debug). Call from Draw or over emissive glow.
function scr_enemy_draw_main_sprite() {
    var _shake_x = (variable_instance_exists(id, "telegraph_shake_x") ? telegraph_shake_x : 0);
    var _shake_y = (variable_instance_exists(id, "telegraph_shake_y") ? telegraph_shake_y : 0);
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    var _draw_x = floor(x + _shake_x);
    // Add hover after floor so sub-pixel sine motion stays smooth on pixel-art sprites
    var _draw_y = floor(y + _shake_y) + _hover_y;

    var _draw_col = image_blend;
    if (variable_instance_exists(id, "gnd_state")) {
        if (gnd_state == GND_STATE_CHASE) _draw_col = merge_color(_draw_col, c_yellow, 0.18);
        else if (gnd_state == GND_STATE_ATTACK) _draw_col = merge_color(_draw_col, c_orange, 0.28);
        else if (gnd_state == GND_STATE_DAMAGED) _draw_col = merge_color(_draw_col, c_aqua, 0.22);
    }
    if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
        _draw_col = merge_color(_draw_col, c_red, 0.45);
    }
    var _crystal = undefined;
    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _crystal = scr_bulb_player_crystal_influence(x, y - 16);
        if (_crystal.strength > 0) {
            var _tint = global.bulb_renderer.normalMap ? 0.18 : 0.55;
            _draw_col = merge_colour(_draw_col, _crystal.blend, _crystal.strength * _tint);
        }
    }

    draw_sprite_ext(sprite_index, image_index, _draw_x, _draw_y,
        scr_enemy_draw_xscale(), image_yscale, image_angle, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined && global.bulb_renderer.normalMap) {
            var _wrap = { strength: _crystal.strength, blend: _crystal.blend, dir: (_crystal.dir + 180) mod 360 };
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x, _draw_y,
                scr_enemy_draw_xscale(), image_yscale, _wrap, image_alpha * 0.32);
        } else {
            scr_bulb_draw_crystal_rim(sprite_index, image_index, _draw_x, _draw_y,
                scr_enemy_draw_xscale(), image_yscale, _crystal, image_alpha);
        }
    }
}

/// @description obj_enemy_parent body draw (state tint / hit blink).
function scr_enemy_parent_draw_main_sprite() {
    var _c = c_white;
    if (variable_instance_exists(id, "gnd_state")) {
        if (gnd_state == 1) _c = merge_color(c_white, c_yellow, 0.22);
        else if (gnd_state == 2) _c = merge_color(c_white, c_orange, 0.4);
        else if (gnd_state == 3) _c = merge_color(c_white, c_aqua, 0.28);
    }
    if (variable_instance_exists(id, "hit_blink_timer") && hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
        _c = merge_color(_c, c_red, 0.55);
    }

    var _draw_col = _c;
    var _crystal = undefined;
    if (variable_global_exists("bulb_renderer") && global.bulb_renderer != undefined) {
        _crystal = scr_bulb_player_crystal_influence(x, y - 16);
        if (_crystal.strength > 0) {
            var _tint = global.bulb_renderer.normalMap ? 0.18 : 0.55;
            _draw_col = merge_colour(_draw_col, _crystal.blend, _crystal.strength * _tint);
        }
    }

    draw_sprite_ext(sprite_index, image_index, floor(x), floor(y),
        image_xscale, image_yscale, image_angle, _draw_col, image_alpha);

    if (_crystal != undefined && _crystal.strength > 0) {
        scr_bulb_draw_crystal_rim(sprite_index, image_index, floor(x), floor(y),
            image_xscale, image_yscale, _crystal, image_alpha);
    }
}
