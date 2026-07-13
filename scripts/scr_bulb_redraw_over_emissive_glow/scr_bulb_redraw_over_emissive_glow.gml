/// @description Restore a lit sprite sample over emissive overlays (keeps normal maps).
/// @param {Id.Surface} _lit_surface Lit composite from Bulb GetOutputSurface
/// @param {Id.Camera} _cam
/// @param {Real} _dx
/// @param {Real} _dy
/// @param {Asset.GMSprite} _spr
/// @param {Real} _img
/// @param {Real} _xscale
/// @param {Real} _yscale
/// @param {Real} _angle
/// @param {Real} _alpha
function scr_bulb_draw_lit_sprite_ext(_lit_surface, _cam, _dx, _dy, _spr, _img, _xscale, _yscale, _angle, _alpha) {
    if (_lit_surface == -1 || !surface_exists(_lit_surface)) {
        draw_sprite_ext(_spr, _img, _dx, _dy, _xscale, _yscale, _angle, c_white, _alpha);
        return;
    }

    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = camera_get_view_width(_cam);
    var _vh = camera_get_view_height(_cam);

    static _u_lit = shader_get_sampler_index(shd_bulb_redraw_lit_sprite, "u_sLit");
    static _u_view_pos = shader_get_uniform(shd_bulb_redraw_lit_sprite, "u_vViewPos");
    static _u_view_size = shader_get_uniform(shd_bulb_redraw_lit_sprite, "u_vViewSize");

    var _old_tex = gpu_get_texfilter();
    var _old_blend = gpu_get_blendmode();
    var _old_alpha = draw_get_alpha();
    var _old_col = draw_get_color();

    gpu_set_texfilter(false);
    gpu_set_blendmode(bm_normal);
    draw_set_color(c_white);
    draw_set_alpha(_alpha);

    shader_set(shd_bulb_redraw_lit_sprite);
    texture_set_stage(_u_lit, surface_get_texture(_lit_surface));
    shader_set_uniform_f(_u_view_pos, _vx, _vy);
    shader_set_uniform_f(_u_view_size, _vw, _vh);
    draw_sprite_ext(_spr, _img, _dx, _dy, _xscale, _yscale, _angle, c_white, _alpha);
    shader_reset();

    gpu_set_texfilter(_old_tex);
    draw_set_alpha(_old_alpha);
    draw_set_color(_old_col);
    gpu_set_blendmode(_old_blend);
}

/// @description Restore the already-lit player sprite over emissive overlays (keeps normal maps).
/// @param {Id.Surface} _lit_surface Lit composite from Bulb GetOutputSurface
/// @param {Id.Camera} _cam
function scr_bulb_draw_player_lit_sprite(_lit_surface, _cam) {
    var _draw_x = floor(x);
    var _draw_y = floor(y);
    var _wall_draw_nudge = 0;
    if (sprite_index == spr_mc_walljump && variable_instance_exists(id, "wall_side") && wall_side != 0) {
        _wall_draw_nudge = wall_side * WALL_CLING_DRAW_NUDGE_PX;
    }

    scr_bulb_draw_lit_sprite_ext(_lit_surface, _cam, _draw_x + _wall_draw_nudge, _draw_y,
        sprite_index, image_index, image_xscale, image_yscale, 0, image_alpha);
}

/// @description Restore the already-lit obj_enemy sprite over emissive overlays.
function scr_bulb_draw_enemy_lit_sprite(_lit_surface, _cam) {
    var _shake_x = (variable_instance_exists(id, "telegraph_shake_x") ? telegraph_shake_x : 0);
    var _shake_y = (variable_instance_exists(id, "telegraph_shake_y") ? telegraph_shake_y : 0);
    var _hover_y = scr_enemy_floating_hover_draw_offset_y();
    scr_bulb_draw_lit_sprite_ext(_lit_surface, _cam, floor(x + _shake_x), floor(y + _shake_y) + _hover_y,
        sprite_index, image_index, scr_enemy_draw_xscale(), image_yscale, image_angle, image_alpha);
}

/// @description Restore the already-lit obj_enemy_parent sprite over emissive overlays.
function scr_bulb_draw_enemy_parent_lit_sprite(_lit_surface, _cam) {
    scr_bulb_draw_lit_sprite_ext(_lit_surface, _cam, floor(x), floor(y),
        sprite_index, image_index, image_xscale, image_yscale, image_angle, image_alpha);
}

/// @description Redraw actors over additive emissive layers (lit restore when normal maps are on).
/// @param {Id.Surface} [_lit_surface]
function scr_bulb_redraw_over_emissive_glow(_lit_surface = -1) {
    var _need = BULB_GLOW_TILE_LAYER_ENABLED || BULB_CRYSTAL_SPARKS_ENABLED;
    if (!_need) return;

    var _cam = view_camera[0];
    if (instance_exists(obj_camera_controller)) {
        _cam = obj_camera_controller.cam;
    }

    camera_apply(_cam);

    var _old_blend = gpu_get_blendmode();
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);

    var _use_lit = variable_global_exists("bulb_renderer")
        && global.bulb_renderer != undefined
        && global.bulb_renderer.normalMap
        && _lit_surface != -1
        && surface_exists(_lit_surface);

    with (obj_player) {
        if (!visible) continue;

        if (_use_lit) {
            scr_bulb_draw_player_lit_sprite(_lit_surface, _cam);
        } else {
            scr_player_draw_main_sprite();
        }
    }

    with (obj_enemy_parent) {
        if (!visible) continue;

        if (object_index == obj_enemy) {
            if (_use_lit) {
                scr_bulb_draw_enemy_lit_sprite(_lit_surface, _cam);
            } else {
                scr_enemy_draw_main_sprite();
            }
        } else {
            if (_use_lit) {
                scr_bulb_draw_enemy_parent_lit_sprite(_lit_surface, _cam);
            } else {
                scr_enemy_parent_draw_main_sprite();
            }
        }
    }

    gpu_set_blendmode(_old_blend);
}

/// @description Cache / resize the lit-scene snapshot surface on obj_bulb_controller.
/// @param {Id.Instance} _controller
/// @param {Id.Surface} _lit_source
/// @returns {Id.Surface}
function scr_bulb_ensure_lit_scene_cache(_controller, _lit_source) {
    with (_controller) {
        var _w = surface_get_width(_lit_source);
        var _h = surface_get_height(_lit_source);

        if (!variable_instance_exists(id, "lit_scene_surface") || lit_scene_surface == -1 || !surface_exists(lit_scene_surface)
            || surface_get_width(lit_scene_surface) != _w || surface_get_height(lit_scene_surface) != _h) {
            if (variable_instance_exists(id, "lit_scene_surface") && lit_scene_surface != -1 && surface_exists(lit_scene_surface)) {
                surface_free(lit_scene_surface);
            }
            lit_scene_surface = surface_create(_w, _h);
        }

        surface_copy(lit_scene_surface, 0, 0, _lit_source);
        return lit_scene_surface;
    }
}

/// @description Draw the lit composite to the back buffer (replaces BulbDrawLitSurface when emissive overlays follow).
/// @param {Struct.BulbRenderer} _renderer
/// @returns {Id.Surface} Cached lit surface for player redraw, or -1
function scr_bulb_draw_lit_scene(_renderer) {
    var _lit = _renderer.GetOutputSurface(application_surface);
    var _pos = application_get_position();
    var _x = _pos[0];
    var _y = _pos[1];
    var _w = _pos[2] - _x;
    var _h = _pos[3] - _y;

    draw_surface_stretched(_lit, _x, _y, _w, _h);
    return scr_bulb_ensure_lit_scene_cache(obj_bulb_controller, _lit);
}
