scr_enemy_draw_main_sprite();
scr_enemy_impact_spark_draw();
scr_enemy_raycast_debug_draw();

// Debug Draw Collision Points
if (global.show_debug) {
    draw_set_color(c_red);
    var _side_dist = floor((bbox_right - bbox_left) * 0.5) - 1;
    var _waist_y = floor((bbox_top + bbox_bottom) * 0.5);
    draw_circle(floor(x) + _side_dist, _waist_y, 2, false);
    draw_circle(floor(x) - _side_dist, _waist_y, 2, false);
    draw_circle(floor(x), floor(bbox_bottom + 1), 2, false);
    draw_set_color(c_white);
    if (instance_exists(obj_player)) {
        draw_set_halign(fa_center);
        draw_text(x, bbox_top - 18, "st:" + string(state) + " hsp:" + string(hsp)
            + " gap:" + string(scr_enemy_hgap_to_player()) + " gnd:" + string(enemy_grounded)
            + (enemy_hmove_blocked ? " BLOCKED" : ""));
        draw_set_halign(fa_left);
    }
}
