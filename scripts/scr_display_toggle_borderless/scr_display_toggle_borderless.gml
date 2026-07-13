/// @file scr_display_toggle_borderless.gml
/// @description Toggle borderless fullscreen vs last windowed size/position.

#macro DISPLAY_BORDERLESS_TOGGLE_KEY vk_f11

/// @function scr_display_toggle_borderless
function scr_display_toggle_borderless() {
    if (!variable_global_exists("display_borderless")) {
        global.display_borderless = false;
    }

    if (!global.display_borderless) {
        global.display_windowed_w = window_get_width();
        global.display_windowed_h = window_get_height();
        global.display_windowed_x = window_get_x();
        global.display_windowed_y = window_get_y();

        window_set_fullscreen(false);
        window_set_showborder(false);
        window_set_size(display_get_width(), display_get_height());
        window_set_position(0, 0);
        global.display_borderless = true;
    } else {
        window_set_fullscreen(false);
        window_set_showborder(true);

        var _w = (variable_global_exists("display_windowed_w") ? global.display_windowed_w : 1280);
        var _h = (variable_global_exists("display_windowed_h") ? global.display_windowed_h : 720);
        var _x = (variable_global_exists("display_windowed_x") ? global.display_windowed_x : -1);
        var _y = (variable_global_exists("display_windowed_y") ? global.display_windowed_y : -1);

        window_set_size(_w, _h);
        if (_x >= 0 && _y >= 0) {
            window_set_position(_x, _y);
        } else {
            window_center();
        }
        global.display_borderless = false;
    }
}
