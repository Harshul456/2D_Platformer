/// @description Paired Laigter normal-map sprite for a player diffuse sprite.
/// Movement/Draw keep spr_mc_idle etc.; Bulb normal pass uses spr_mc_idle_n via this lookup.
/// @param {Asset.GMSprite} _diffuse
/// @returns {Asset.GMSprite} Normal sprite, or -1 if none.
function scr_bulb_sprite_to_normal(_diffuse) {
    switch (_diffuse) {
        case spr_mc_idle:       return spr_mc_idle_n;
        case spr_mc_jog:        return spr_mc_jog_n;
        case spr_mc_sprint:     return spr_mc_sprint_n;
        case spr_mc_jump:       return spr_mc_jump_n;
        case spr_mc_walljump:   return spr_mc_walljump_n;
        case spr_mc_doublejump: return spr_mc_doublejump_n;
        case spr_mc_reelback:   return spr_mc_reelback_n;
        case spr_asta_attack1:  return spr_asta_attack1_n;
        case spr_mc_attack2:    return spr_mc_attack2_n;
        case spr_mc_hurt:       return spr_mc_hurt_n;
        case spr_mc_hurt_air:   return spr_mc_hurt_air_n;
        case spr_enemy:         return spr_enemy_n;
        case spr_enemy_windup:  return spr_enemy_windup_n;
        case spr_enemy_attack:  return spr_enemy_attack_n;
        default:                return -1;
    }
}

/// @description Draw a Laigter normal map into Bulb's normal surface.
/// @param {Asset.GMSprite} _diffuse
/// @param {Real} _image
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} _xscale
/// @param {Real} _yscale
/// @param {Real} _angle
function scr_bulb_draw_laigter_normal(_diffuse, _image, _x, _y, _xscale, _yscale, _angle) {
    var _normal = scr_bulb_sprite_to_normal(_diffuse);

    if (_normal != -1) {
        // Laigter maps are already in tangent space — do NOT run Bulb's silhouette normal shader.
        BulbNormalMapShaderReset();
        draw_sprite_ext(_normal, _image, _x, _y, _xscale, _yscale, _angle, c_white, 1);
    } else {
        BulbNormalMapShaderSet(true);
        BulbNormalMapDrawSpriteExt(_diffuse, _image, _x, _y, _xscale, _yscale, _angle);
    }
}
