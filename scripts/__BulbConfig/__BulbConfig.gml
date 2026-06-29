// Distance around the edge of the camera (in pixels) to draw dynamic occluders. Increase this
// number if you have large dynamic occluders and are experiencing pop-in.
#macro BULB_DYNAMIC_OCCLUDER_RANGE  100

// Adds an extra triangle for each occluder to compensate for situations where a light might be
// very close to an occluder. Normally, this would cause light to bleed through the wall. Setting
// this macro to `true` will solve near-light problems but does incur a slight performance penalty.
#macro BULB_COMPENSATE_FOR_NEAR_OCCLUDERS  true

// Whether renderers, lights, and sunlight should default to having normal map support enabled.
// This saves a lot of time setting `.normalMap` on everything that you create. Enabling normal
// maps has a significant performance penalty so use this carefully.
#macro BULB_DEFAULT_USE_NORMAL_MAP  false

// The alpha threshold for sprites when drawing to the normal/specular map. Anything below this
// value will be discarded by the shader.
#macro BULB_NORMAL_MAP_ALPHA_THRESHOLD  0.5

// How intense the specular map effect should be. This generally is only noticeable when using HDR
// lighting. The specular map is packed into the alpha channel of the normal map surface.
#macro BULB_SPECULAR_MAP_INTENSITY  10.0

// The default notional "z height" for lights and sunlight. This z value is only used when
// calculating normal map influence on lights. A lower value brings the light closer to the plane,
// leading to a shallower angle of attack. This leads to more intense normal maps where the edges
// of shapes will be highlighted more strongly than the tops of shapes, especially at distance.
#macro BULB_DEFAULT_NORMAL_MAP_Z  0.2

// Normal-map lighting (Laigter player + flat tile normals). Press F8 in-game to toggle.
#macro BULB_NORMAL_MAPS_ENABLED       true
#macro BULB_NORMAL_MAP_TOGGLE_KEY     vk_f8

// Player torch BulbLight (warm glow centered on the player).
#macro BULB_PLAYER_TORCH_ENABLED  true

// Crystal light height for normal-map shading. Side-mounted crystals need a LOWER Z than an
// on-body torch — high Z makes the light come from almost straight above, so Lambert dot(N,L)
// barely varies across the body and reads flat. Player torch uses 40 in Step_0.
#macro BULB_CRYSTAL_NORMAL_MAP_Z  40

// Hidden glow-mask tile layer (ts_foreground_glow) — drawn additively in obj_bulb_controller Post Draw.
// Tile emissive alpha uses the same pulse phase as the matching obj_bulb_crystal_light Bulb circle.
#macro BULB_GLOW_TILE_LAYER_ENABLED  true
#macro BULB_GLOW_TILE_LAYER           "tiles_glow"
#macro BULB_GLOW_TILESET              ts_foreground_glow

// Shared crystal breathe — tight phase shrinks Bulb circle + dims tile glow together.
#macro BULB_CRYSTAL_PULSE_SCALE_TIGHT       0.65
#macro BULB_CRYSTAL_PULSE_SCALE_WIDE         1.14
#macro BULB_CRYSTAL_PULSE_INTENSITY_TIGHT    0.72
#macro BULB_CRYSTAL_PULSE_INTENSITY_WIDE     1.12
#macro BULB_GLOW_PULSE_MIN                   0.48
#macro BULB_GLOW_PULSE_MAX                   1.0

// Crisp white sparkles orbiting crystals (additive shimmer, not rising embers).
#macro BULB_CRYSTAL_SPARKS_ENABLED           true
#macro BULB_CRYSTAL_SPARK_MAX                8
#macro BULB_CRYSTAL_SPARK_RATE_MIN           0.03
#macro BULB_CRYSTAL_SPARK_RATE_MAX           0.14
#macro BULB_CRYSTAL_SPARK_ALPHA              0.42
#macro BULB_CRYSTAL_SPARK_LIFE_MIN           90
#macro BULB_CRYSTAL_SPARK_LIFE_MAX           160
#macro BULB_CRYSTAL_SPARK_ORBIT_R_MIN        5
#macro BULB_CRYSTAL_SPARK_ORBIT_R_MAX        16
#macro BULB_CRYSTAL_SPARK_ORBIT_SPEED_MIN    0.35
#macro BULB_CRYSTAL_SPARK_ORBIT_SPEED_MAX    1.05
#macro BULB_CRYSTAL_SPARK_WOBBLE             1.6
#macro BULB_CRYSTAL_SPARK_CENTER_Y           -6

// Ambient cave dust / spores — random motes drifting inside the camera view.
#macro BULB_CAVE_DUST_ENABLED                true
#macro BULB_CAVE_DUST_COUNT_MIN              38
#macro BULB_CAVE_DUST_COUNT_MAX              72
#macro BULB_CAVE_DUST_AREA_DIV               14500
#macro BULB_CAVE_DUST_ALPHA                  0.32
#macro BULB_CAVE_DUST_COL_R                  168
#macro BULB_CAVE_DUST_COL_G                  178
#macro BULB_CAVE_DUST_COL_B                  196
#macro BULB_CAVE_DUST_DRIFT                  0.14
#macro BULB_CAVE_DUST_WOBBLE                 0.9
#macro BULB_CAVE_DUST_LIFE_MIN               220
#macro BULB_CAVE_DUST_LIFE_MAX               380
#macro BULB_CAVE_DUST_SPAWN_PAD              24
#macro BULB_CAVE_DUST_CULL_MARGIN            32

// Ceiling stalactite drips — spawned from Tiles_Ceiling_Drips, splash on lay_collision.
#macro BULB_CEILING_DRIP_ENABLED             true
#macro BULB_CEILING_DRIP_LAYER               "Tiles_Ceiling_Drips"
#macro BULB_CEILING_DRIP_SPAWN_Y_FRAC        0.92
#macro BULB_CEILING_DRIP_INTERVAL_MIN        110
#macro BULB_CEILING_DRIP_INTERVAL_MAX        300
#macro BULB_CEILING_DRIP_MAX_ACTIVE          22
#macro BULB_CEILING_DRIP_MAX_SPLASH          16
#macro BULB_CEILING_DRIP_FALL_SPEED          2.35
#macro BULB_CEILING_DRIP_MAX_FALL            720
#macro BULB_CEILING_DRIP_FLOOR_STEP           2
#macro BULB_CEILING_DRIP_X_JITTER            3
#macro BULB_CEILING_DRIP_VIEW_PAD            96
#macro BULB_CEILING_DRIP_ALPHA               0.82
#macro BULB_CEILING_DRIP_SPLASH_ALPHA        0.7
#macro BULB_CEILING_DRIP_SPLASH_FRAME_LEN    4

// Cave atmosphere — drifting mist (behind player) + screen-edge vignette.
#macro BULB_CAVE_FOG_ENABLED                 false
#macro BULB_CAVE_FOG_LAYER                    "Tiles_Cave_Fog"
#macro BULB_CAVE_FOG_DRIFT_SPEED              0.22
#macro BULB_CAVE_FOG_LAYER_PARALLAX           0.45
#macro BULB_CAVE_FOG_ALPHA                    0.09
#macro BULB_CAVE_FOG_TILE_ALPHA               0.14
#macro BULB_CAVE_FOG_COL_R                    148
#macro BULB_CAVE_FOG_COL_G                    158
#macro BULB_CAVE_FOG_COL_B                    172
#macro BULB_CAVE_FOG_BAND_SPACING             56
#macro BULB_CAVE_FOG_BAND_HEIGHT              22
#macro BULB_CAVE_FOG_CHUNK_W                  112

#macro BULB_CAVE_VIGNETTE_ENABLED             false
#macro BULB_CAVE_VIGNETTE_STRENGTH            0.52
#macro BULB_CAVE_VIGNETTE_SOFTNESS            0.38