// --- 0. PRE-RENDER CALCULATIONS ---
// Debug sensor visualization derives from mask, not hard-coded constants
var _side_dist = floor((bbox_right - bbox_left) * 0.5) - 1;

// --- 1. REFLECTION (Professional strip-based clipping) ---
// Draw reflection in vertical strips, only showing parts directly over tiles
// This matches how Celeste, Ori, and other professional platformers handle reflections
var _feet_y = floor(bbox_bottom);
var _in_x_bounds = (x >= reflect_region_x1 && x <= reflect_region_x2);

// Check if any part of character is over tiles (for timer management)
var _has_tile_contact = false;
if (global.tilemap_collision_id != noone) {
    var _leftmost = floor(bbox_left);
    var _rightmost = floor(bbox_right);
    var _center = floor((bbox_left + bbox_right) * 0.5);
    _has_tile_contact = check_tile_collision(_leftmost, _feet_y + 1) ||
                        check_tile_collision(_center, _feet_y + 1) ||
                        check_tile_collision(_rightmost, _feet_y + 1);
}

if (_has_tile_contact && _in_x_bounds && global.reflections_enabled) {
    reflect_region_y = _feet_y;
    reflection_timer = reflection_timer_max;
} else if (reflection_timer > 0) {
    reflection_timer--;
}

// Draw reflection with strip-based clipping (only parts over tiles)
// NOTE: draw_sprite_part_ext() positions from the part's top-left (NOT sprite origin),
// so we must offset using the sprite origin to place the flipped image below the feet line.
if (global.reflections_enabled && reflection_timer > 0 && global.tilemap_collision_id != noone) {
    // Reset color state to ensure no blue tint leaks in
    draw_set_color(c_white);
    draw_set_alpha(1.0);
    
    var _reflect_strength = reflection_timer / reflection_timer_max;
    // Pure white - no color tint at all
    var _base_alpha = 0.38 * _reflect_strength;
    var _reflect_col = c_white;
    
    var _spr_w = sprite_get_width(sprite_index);
    var _spr_h = sprite_get_height(sprite_index);
    var _spr_xoff = sprite_get_xoffset(sprite_index);
    var _spr_yoff = sprite_get_yoffset(sprite_index);
    
    // Reflection "origin" line (player feet) — no +2 so we use full 32px of tile (cut below torso)
    var _origin_x = floor(x);
    var _origin_y = floor(bbox_bottom);
    
    // We draw the sprite flipped vertically about its origin:
    // destY for the top of the (source_y=0) rect becomes:
    // origin_y + (0 - yoff) * (-yscale)
    var _dest_y = round(_origin_y + (0 - _spr_yoff) * (-image_yscale));

    // We only reflect the portion above the feet line (source_y 0..yoff). Fade and band sizes
    // come from Create so tuning is in one place (REFLECT_* constants).
    var _src_h_total = max(1, floor(_spr_yoff));
    var _band_h = REFLECT_BAND_HEIGHT;
    var _fade_dist = REFLECT_FADE_DIST;
    var _fade_x = REFLECT_FADE_X;
    var _diag_strength = REFLECT_DIAG_STRENGTH;
    
    var _strip_width = 1;   // Pixel-perfect horizontal clipping (only draw over tiles)
    var _y_check = _feet_y + 1;
    var _x_sign = (image_xscale >= 0) ? 1 : -1;
    
    // Per-strip we scan down to find platform bottom (bounded by REFLECT_PLATFORM_SCAN_MAX so no infinite loop).
    
    for (var _sx = 0; _sx < _spr_w; _sx += _strip_width) {
        var _strip_w = min(_strip_width, _spr_w - _sx);
        
        // Destination X for the left edge of this strip (source_x = _sx)
        var _dest_x = round(_origin_x + (_sx - _spr_xoff) * image_xscale);

        // IMPORTANT: check the *same* pixel column we draw (prevents 1px edge leak).
        var _check_x = _dest_x + (_x_sign < 0 ? -1 : 0);
        
        if (check_tile_collision(_check_x, _y_check)) {
            // Platform depth at this column only — so "tile underneath" vs "no tile" doesn't bleed
            var _platform_bottom = _y_check;
            for (var _s = 0; _s < REFLECT_PLATFORM_SCAN_MAX; _s++) {
                if (!check_tile_collision(_check_x, _platform_bottom + 1)) break;
                _platform_bottom++;
            }
            // Clip at last solid row so reflection doesn't draw below the platform (was +1 = cut too low)
            var _clip_bottom = _platform_bottom;

            // Horizontal component (centered on sprite origin X)
            var _x_center = (_sx + (_strip_w * 0.5));
            var _x_dist = abs(_x_center - _spr_xoff);
            var _x_w = clamp(_x_dist / _fade_x, 0, 1);

            // Draw in horizontal bands to get a smooth vertical fade without a shader
            for (var _sy = 0; _sy < _src_h_total; _sy += _band_h) {
                var _h = min(_band_h, _src_h_total - _sy);
                var _band_center = _sy + (_h * 0.5);
                
                // Distance below the feet line in source space (yoff - source_y)
                var _dist = max(0, _spr_yoff - _band_center);
                var _y_w = clamp(_dist / _fade_dist, 0, 1);
                // Diagonal fade: combine vertical + horizontal falloff
                var _fade_w = clamp(1 - (_y_w + (_x_w * _diag_strength)), 0, 1);
                if (_fade_w <= 0) continue;
                
                // destY for this band at source_y = _sy
                var _dest_y_band = round(_origin_y + (_sy - _spr_yoff) * (-image_yscale));
                var _band_drawn_height = _h * abs(image_yscale);
                var _band_bottom = _dest_y_band + _band_drawn_height;
                // Clip band so it doesn't draw below the platform (stops vertical bleed)
                if (_band_bottom > _clip_bottom) {
                    var _max_height = _clip_bottom - _dest_y_band;
                    if (_max_height <= 0) continue;
                    _h = min(_h, floor(_max_height / abs(image_yscale)));
                    if (_h <= 0) continue;
                }
                
                draw_sprite_part_ext(
                    sprite_index,
                    image_index,
                    _sx,            // Source X
                    _sy,            // Source Y (band)
                    _strip_w,       // Source width
                    _h,             // Source height (band height, possibly clipped)
                    _dest_x,        // Dest X
                    _dest_y_band,   // Dest Y (top-left of the band in world space)
                    image_xscale,   // X scale (preserve facing)
                    -image_yscale,  // Y scale (vertical flip)
                    _reflect_col,
                    _base_alpha * _fade_w
                );
            }
        }
    }
}

// --- 2. MAIN RENDERING ---
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y), 
                image_xscale, image_yscale, 0, c_white, image_alpha);

// --- 3. DEBUG OVERLAY ---
if (global.show_debug) {
    var _px = floor(x);
    var _py = floor(y);
    
    draw_set_color(c_aqua);
    draw_circle(_px - _side_dist, _py + 1, 2, false);
    draw_circle(_px, _py + 1, 2, false);
    draw_circle(_px + _side_dist, _py + 1, 2, false);
}

draw_set_alpha(1.0);
draw_set_color(c_white);