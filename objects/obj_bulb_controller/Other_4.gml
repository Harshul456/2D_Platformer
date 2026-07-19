// The decorative "foreground" crystal layer authors at depth 0 (in front of the actors), so any time
// the player walks under a crystal overhang it reads as "phasing through" the opaque tiles. This is a
// separate issue from the pink emissive glow (that's handled by the lit-snapshot + mask-shader restore
// in scr_bulb_redraw_over_emissive_glow): the foreground is opaque art baked into the lit snapshot, so
// the restore can't recover the player pixels there. Fix it at the source by pushing the foreground
// layer just behind the actor layer (depth: higher = further back) so player/enemies always draw on
// top. Lighting is untouched — occluders/normals reference layers by name, not depth.
var _fg_layer = layer_get_id("foreground");
if (_fg_layer != -1) {
    var _actor_depth = 100;
    if (instance_exists(obj_player)) _actor_depth = layer_get_depth(obj_player.layer);
    layer_depth(_fg_layer, _actor_depth + 50);
}

scr_bulb_spawn_crystal_lights("near_tiles");



// Bake occluders here — Room Start runs on frozen instances; Alarm does not.

scr_bulb_destroy_all_tilemap_occluders(renderer, tilemap_occluders);

tilemap_occluders = scr_bulb_build_room_occluders(renderer);

occluders_built = true;

scr_ceiling_drip_bake_emitters(id, BULB_CEILING_DRIP_LAYER);
scr_cave_atmosphere_bind_fog_layer(id);