// --- 0. PRE-RENDER CALCULATIONS ---
var _cx = floor(camera_get_view_x(view_camera[0]));
var _cy = floor(camera_get_view_y(view_camera[0]));
var _vw = camera_get_view_width(view_camera[0]);
var _vh = camera_get_view_height(view_camera[0]);
var side_dist = 13;

// --- 1. REFLECTION SURFACE ---
if (!surface_exists(surf_reflection)) {
    surf_reflection = surface_create(_vw, _vh);
}

// Create temp surface once and reuse
if (!surface_exists(surf_temp_reflection)) {
    surf_temp_reflection = surface_create(max_reflection_size, max_reflection_size);
}

// IMPORTANT: Set target for main reflection surface
surface_set_target(surf_reflection);
draw_clear_alpha(c_white, 0);

var lay_col_id = layer_get_id("lay_collision"); 
var map_col_id = layer_tilemap_get_id(lay_col_id);

if (layer_exists(lay_col_id)) {
    var _on_platform = check_tile_collision(floor(x) - 10, floor(y) + 1) || 
                       check_tile_collision(floor(x) + 10, floor(y) + 1);
    
    if (grounded && _on_platform) {
        var spr_w = sprite_get_width(sprite_index);
        var spr_h = sprite_get_height(sprite_index);
        var max_reflection_dist = spr_h * 0.6;
        
        // CRITICAL: Reset before switching to temp surface
        surface_reset_target();
        
        // Now draw to temp surface
        surface_set_target(surf_temp_reflection);
        draw_clear_alpha(c_black, 0);
        
        draw_sprite_ext(
            sprite_index,
            image_index,
            spr_w / 2,
            0,
            image_xscale,
            -image_yscale,
            0,
            c_white,
            1
        );
        
        // Reset temp surface
        surface_reset_target();
        
        // Switch back to main reflection surface
        surface_set_target(surf_reflection);
        
        // Draw strips
        var strips = 10;
        var strip_height = max_reflection_dist / strips;
        
        gpu_set_blendmode(bm_normal);
        
        for (var i = 0; i < strips; i++) {
            var fade = 1 - (i / strips);
            var alpha = 0.45 * fade;
            
            draw_surface_part_ext(
                surf_temp_reflection,
                0,
                i * strip_height,
                spr_w,
                strip_height,
                floor(x) - _cx - spr_w / 2,
                floor(y) + 2 - _cy + (i * strip_height),
                1, 1,
                c_white,
                alpha
            );
        }
    }
}

// CRITICAL: Always reset at the end
surface_reset_target();

// --- 2. MAIN RENDERING ---
draw_surface(surf_reflection, _cx, _cy);
draw_sprite_ext(sprite_index, image_index, floor(x), floor(y), 
                image_xscale, image_yscale, 0, c_white, image_alpha);

// --- 3. DEBUG OVERLAY ---
if (global.show_debug) {
    var _px = floor(x);
    var _py = floor(y);
    
    draw_set_color(c_aqua);
    draw_circle(_px - side_dist, _py + 1, 2, false);
    draw_circle(_px, _py + 1, 2, false);
    draw_circle(_px + side_dist, _py + 1, 2, false);
}

draw_set_alpha(1.0);
draw_set_color(c_white);