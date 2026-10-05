/// Draw body with charge flash (skip parent ATTACK orange tint).
var _hover_y = scr_enemy_floating_hover_draw_offset_y();

// White freeze-flash before shatter
if (gnd_state == GND_STATE_DEAD) {
    scr_enemy_draw_death_flash();
    exit;
}

var _shake_x = telegraph_shake_x;
var _shake_y = telegraph_shake_y;
var _draw_x = floor(x + _shake_x);
var _draw_y = floor(y + _shake_y) + _hover_y;

var _col = image_blend;
if (gnd_state == GND_STATE_CHASE) {
    _col = merge_color(_col, c_aqua, 0.12);
}
if (hit_blink_timer > 0 && ((hit_blink_timer div 3) mod 2 == 0)) {
    _col = merge_color(_col, c_red, 0.45);
}

var _xs = scr_enemy_draw_xscale();
var _lean = scr_enemy_draw_lean_angle();
draw_sprite_ext(sprite_index, image_index, _draw_x, _draw_y,
    _xs, image_yscale, _lean, _col, image_alpha);

if (global.show_debug) {
    var _core = scr_ancient_rock_core_xy();
    draw_set_color(c_lime);
    draw_circle(floor(_core.x), floor(_core.y), 2, false);
    draw_set_color(c_aqua);
    draw_circle(floor(x), floor(y) + _hover_y, 2, false);
    draw_set_halign(fa_center);
    draw_text(x, bbox_top - 14 + _hover_y,
        "air y:" + string(floor(ystart)) + " st:" + string(gnd_state)
        + " cd:" + string(rock_cooldown));
    draw_set_halign(fa_left);
    draw_set_color(c_white);
}
