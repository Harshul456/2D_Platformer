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

// HDR bloom — on by default; press F9 in-game to toggle it off.
// Tuned so bloom only glows genuine highlights (light cores / crystals) instead of
// washing the whole scene: neutral exposure + high threshold + visible intensity.
#macro BULB_HDR_BLOOM_DEFAULT_ON        true
#macro BULB_HDR_BLOOM_INTENSITY         0.28   // Glow strength on the highlights that pass threshold
#macro BULB_HDR_BLOOM_ITERATIONS        3      // Wider, softer falloff
#macro BULB_HDR_BLOOM_THRESHOLD_MIN     1.02   // Only bright crystal/light cores bloom (higher = less scene lift)
#macro BULB_HDR_BLOOM_THRESHOLD_MAX     1.40   // Full bloom above this
#macro BULB_HDR_EXPOSURE                0.94   // Slightly under 1 to keep the dark, moody cave (was 1.16)
#macro BULB_HDR_BLOOM_TOGGLE_KEY        vk_f9

// Cave ambient — dark mood, but high enough to read platforms between lights.
#macro BULB_AMBIENT_R                   22
#macro BULB_AMBIENT_G                   26
#macro BULB_AMBIENT_B                   40

// Player torch BulbLight (warm glow centered on the player).
#macro BULB_PLAYER_TORCH_ENABLED        true
#macro BULB_PLAYER_TORCH_INTENSITY      1.32
#macro BULB_PLAYER_TORCH_SCALE          1.62
#macro BULB_PLAYER_TORCH_Y_OFFSET       -12
#macro BULB_PLAYER_TORCH_CRYSTAL_DIM    0.94

// Always-on readability rim — soft cool edge so the player holds silhouette in dark cave areas.
// Not a thick cartoon outline; additive 1px catch-light (stronger during Perfect Dodge).
#macro BULB_PLAYER_READABILITY_RIM_ENABLED   true
#macro BULB_PLAYER_READABILITY_RIM_DIST      1
#macro BULB_PLAYER_READABILITY_RIM_ALPHA     0.16
#macro BULB_PLAYER_READABILITY_RIM_PD_MULT   1.55
#macro BULB_PLAYER_READABILITY_RIM_R         210
#macro BULB_PLAYER_READABILITY_RIM_G         230
#macro BULB_PLAYER_READABILITY_RIM_B         255

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

// Moving crystal enemies — self-emissive light + additive glow overlay (same pipeline as tile crystals).
#macro BULB_ENEMY_CRYSTAL_LIGHT_ENABLED        true
#macro BULB_ENEMY_GLOW_ENABLED                 true
#macro BULB_ENEMY_GLOW_SPRITE                  spr_crystal_core_glow  // Idle / patrol / chase
#macro BULB_ENEMY_GLOW_SPRITE_WINDUP           spr_crystal_core_windup_glow
#macro BULB_ENEMY_GLOW_SPRITE_ATTACK           spr_crystal_core_attack_glow
#macro BULB_ENEMY_GLOW_ALPHA                   1.0    // Scales flare alpha (tile glow uses art color + pulse only)
#macro BULB_ENEMY_LIGHT_SCALE                  0.88   // Bulb circle vs tile crystal lights
#macro BULB_ENEMY_LIGHT_Y_OFFSET               -14    // Light anchor above feet (sprite center mass)
#macro BULB_ANCIENT_ROCK_LIGHT_SCALE           0.92   // Soft air-enemy blue halo
#macro BULB_ANCIENT_ROCK_GLOW_BLEND            make_colour_rgb(72, 168, 255)  // Cool blue emissive tint
#macro BULB_ANCIENT_ROCK_LIGHT_BLEND           make_colour_rgb(90, 175, 255)  // Bulb circle blue
#macro BULB_ANCIENT_ROCK_LIGHT_INTENSITY       1.32
#macro BULB_ANCIENT_ROCK_CRYSTAL_KIND          2      // Blue kind in scr_bulb_crystal_light_apply
#macro BULB_ANCIENT_ROCK_CORE_Y_OFFSET         -30    // Teal diamond center (64px sprite, bottom origin)

// Enemy hit reaction — emissive flare + expanding light ripple (glow driven by hits, not breathe).
#macro BULB_ENEMY_GLOW_BASE                    0.5    // Resting emissive glow when not hit (decoupled from breathe)
#macro BULB_ENEMY_HIT_GLOW_BOOST               0.22   // Subtle brightening on hit (kept low — ripple carries the reaction)
#macro BULB_ENEMY_HIT_GLOW_DECAY               0.055  // Per-frame flare falloff
// Water-drop ripple — the enemy light radius undulates in a damped wave when hit.
// Disabled: the pulsing light edge read as a visible circle; the distortion shockwave carries the ripple now.
#macro BULB_ENEMY_HIT_RIPPLE_ENABLED           false
#macro BULB_ENEMY_HIT_RIPPLE_LIFE              40     // Frames the ripple lasts before settling
#macro BULB_ENEMY_HIT_RIPPLE_WAVES             4.0    // Expand/contract oscillations (more = wobblier water)
#macro BULB_ENEMY_HIT_RIPPLE_AMPLITUDE         0.42   // Peak radius swing (fraction of base scale)
#macro BULB_ENEMY_HIT_RIPPLE_DAMP              0.10   // Exponential decay per frame (higher = settles faster)
#macro BULB_ENEMY_HIT_RIPPLE_INTENSITY_MOD     0.12   // How much brightness follows the ripple (low = no flash)

// Screen-space distortion shockwave — the scene refracts/warps outward on hit (no colored ring).
#macro HIT_DISTORT_ENABLED                     true
#macro HIT_DISTORT_MAX                         8      // Max simultaneous ripples the shader handles
#macro HIT_DISTORT_LIFE                        42     // Frames a ripple expands before it dies (higher = slower)
#macro HIT_DISTORT_R0                          0.02   // Start radius (fraction of view width)
#macro HIT_DISTORT_RMAX                        0.42   // End radius (fraction of view width), scaled by strength
#macro HIT_DISTORT_WIDTH                       0.075  // Band half-width of the warp (wider = softer, less line-like)
#macro HIT_DISTORT_STRENGTH                    0.014  // Peak UV displacement (fraction of view) — the warp amount

// Expanding light burst riding the shockwave — a real Bulb light so the cave rock actually lights up
// (normal-mapped) as the ring spreads, then fades. Shares the distortion ripple's life/center.
#macro HIT_LIGHT_ENABLED                       true
#macro HIT_LIGHT_COLOR                         make_colour_rgb(255, 206, 232)  // warm pink-white energy flash
#macro HIT_LIGHT_INTENSITY                     2.4    // Peak brightness at impact (decays as the ring expands)
#macro HIT_LIGHT_SCALE_START                   0.35   // sLight128 scale at spawn — tight bright core on the hit
#macro HIT_LIGHT_SCALE_END                     2.6    // sLight128 scale at end — how far the glow spreads outward
#macro HIT_LIGHT_FADE_POWER                    1.6    // Intensity falloff curve (higher = snappier flash, longer tail)

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

// Cave fairies — drifting motes that each own a BulbLight. Spawned hovering over pond
// surfaces and scattered through open (non-solid) space across the room. Every fairy is a
// real dynamic light, so keep the counts modest and leave shadow casting off.
#macro BULB_FAIRY_ENABLED                    true
#macro BULB_FAIRY_POND_COUNT                 14
#macro BULB_FAIRY_ROOM_COUNT                 12
#macro BULB_FAIRY_MAX                        32
// Wander: each fairy drifts toward a target picked within this radius of its anchor.
#macro BULB_FAIRY_ROAM_RADIUS                40
#macro BULB_FAIRY_ACCEL                      0.035
#macro BULB_FAIRY_SPEED_MAX                  0.70
#macro BULB_FAIRY_DRAG                       0.94
#macro BULB_FAIRY_RETARGET_MIN               45
#macro BULB_FAIRY_RETARGET_MAX               150
#macro BULB_FAIRY_POND_HOVER_MIN             6
#macro BULB_FAIRY_POND_HOVER_MAX             34
#macro BULB_FAIRY_SPAWN_TRIES                80
// Body: bright core pixel plus dimmer pixels around it (see reference).
#macro BULB_FAIRY_CORE_R                     215
#macro BULB_FAIRY_CORE_G                     248
#macro BULB_FAIRY_CORE_B                     255
#macro BULB_FAIRY_WING_R                     95
#macro BULB_FAIRY_WING_G                     180
#macro BULB_FAIRY_WING_B                     238
#macro BULB_FAIRY_BODY_ALPHA                 0.95
// Wing beat. Degrees per frame, so 42 is roughly seven flaps a second; the gain beats
// faster while the fairy is actually travelling. Span/rise are in pixels and get rounded,
// which is what keeps the flap reading as pixel art instead of a sliding smear.
#macro BULB_FAIRY_WING_SPEED                 42
#macro BULB_FAIRY_WING_SPEED_GAIN            0.60
#macro BULB_FAIRY_WING_SPAN                  2
#macro BULB_FAIRY_WING_RISE                  1.5
#macro BULB_FAIRY_WING_ALPHA_MIN             0.28
#macro BULB_FAIRY_WING_ALPHA_MAX             0.72
// Light
#macro BULB_FAIRY_LIGHT_SPRITE               sLight128
#macro BULB_FAIRY_LIGHT_BLEND                make_colour_rgb(90, 175, 255)
#macro BULB_FAIRY_LIGHT_INTENSITY            0.85
#macro BULB_FAIRY_LIGHT_SCALE                0.30
#macro BULB_FAIRY_LIGHT_NORMAL_MAP_Z         18
// Breathe — light scale/intensity and body alpha share one phase.
#macro BULB_FAIRY_PULSE_SPEED                0.9
#macro BULB_FAIRY_PULSE_MIN                  0.68
#macro BULB_FAIRY_PULSE_MAX                  1.16
#macro BULB_FAIRY_CULL_MARGIN                48

// Waterfall — tile 24 on Tiles_Waterfall (mid copies moved here at bake).
// World-locked X so it stays where you placed it. Depth just in front of mid.
#macro BULB_WATERFALL_ENABLED                true
#macro BULB_WATERFALL_LAYER                  "Tiles_Waterfall"
#macro BULB_WATERFALL_TILE_STREAM            24
#macro BULB_WATERFALL_SCROLL_SPEED           1.35
#macro BULB_WATERFALL_MATCH_MID_PARALLAX     false
// Soft translucent main column (no tile zig-zag). Drawn behind the player.
#macro BULB_WATERFALL_SOFT_STREAM            true
#macro BULB_WATERFALL_SOFT_ALPHA             0.78
#macro BULB_WATERFALL_SOFT_EDGE              3
#macro BULB_WATERFALL_SPARKLE_ENABLED        true
#macro BULB_WATERFALL_SPARKLE_DENSITY        0.055
#macro BULB_WATERFALL_SPARKLE_ALPHA          0.75
#macro BULB_WATERFALL_SPARKLE_SCROLL         2.2

// Waterfall ground splash — dense bubbly foam at stream foot (tile-24 palette).
#macro BULB_WATERFALL_SPLASH_ENABLED         true
#macro BULB_WATERFALL_SPLASH_MAX             220
#macro BULB_WATERFALL_SPLASH_PER_EMITTER     64
#macro BULB_WATERFALL_SPLASH_REFILL          11
#macro BULB_WATERFALL_SPLASH_VIEW_PAD        96
#macro BULB_WATERFALL_SPLASH_WIDTH_PAD       20
#macro BULB_WATERFALL_SPLASH_HEIGHT          18
#macro BULB_WATERFALL_SPLASH_RISE            12
#macro BULB_WATERFALL_SPLASH_LIFE_MIN        20
#macro BULB_WATERFALL_SPLASH_LIFE_MAX        42
#macro BULB_WATERFALL_SPLASH_JITTER          0.22
#macro BULB_WATERFALL_SPLASH_ALPHA           0.7

// Two thinner side-streams spilling from the splash (left + right), soft translucent columns.
#macro BULB_WATERFALL_LEAK_ENABLED           true
#macro BULB_WATERFALL_LEAK_WIDTH             11
#macro BULB_WATERFALL_LEAK_INSET             0
#macro BULB_WATERFALL_LEAK_MAX_FALL          720
#macro BULB_WATERFALL_LEAK_POOL_SNAP         72
#macro BULB_WATERFALL_LEAK_SCROLL_SPEED      0
#macro BULB_WATERFALL_LEAK_ALPHA             0.42
#macro BULB_WATERFALL_LEAK_PLATFORM_MAX_H    96
#macro BULB_WATERFALL_LEAK_FOOT_FOAM         true
#macro BULB_WATERFALL_LEAK_FOOT_PAD          10
#macro BULB_WATERFALL_LEAK_FOOT_BUBBLES      28
#macro BULB_WATERFALL_LEAK_CONNECT_RISE      0
#macro BULB_WATERFALL_GROUND_SHEET_H         8
#macro BULB_WATERFALL_GROUND_SHEET_ALPHA     0.5
#macro BULB_WATERFALL_GROUND_SPARKLE_N       18
#macro BULB_WATERFALL_LEAK_POUR_R            7

// Light blue waterfall palette (stream / splash / sparkles / leaks).
#macro BULB_WATERFALL_COL_BASE_R             72
#macro BULB_WATERFALL_COL_BASE_G             150
#macro BULB_WATERFALL_COL_BASE_B             220
#macro BULB_WATERFALL_COL_MID_R              110
#macro BULB_WATERFALL_COL_MID_G             190
#macro BULB_WATERFALL_COL_MID_B             245
#macro BULB_WATERFALL_COL_BRIGHT_R           165
#macro BULB_WATERFALL_COL_BRIGHT_G           225
#macro BULB_WATERFALL_COL_BRIGHT_B           255
#macro BULB_WATERFALL_COL_FOAM_R             210
#macro BULB_WATERFALL_COL_FOAM_G             240
#macro BULB_WATERFALL_COL_FOAM_B             255

// Waterfall ambient loop — cave reverb + light slap echo; louder near the stream.
#macro BULB_WATERFALL_SFX_ENABLED            true
#macro BULB_WATERFALL_SFX_HEAR_RADIUS        720
#macro BULB_WATERFALL_SFX_VIEW_PAD           160
#macro BULB_WATERFALL_SFX_VOL_MIN            0.18
#macro BULB_WATERFALL_SFX_VOL_MAX            0.85
#macro BULB_WATERFALL_SFX_FADE_MS            250
#macro BULB_WATERFALL_SFX_PITCH              1.0
#macro BULB_WATERFALL_SFX_AUDIO_PRIORITY     8
#macro BULB_WATERFALL_SFX_REVERB_SIZE        0.88
#macro BULB_WATERFALL_SFX_REVERB_DAMP        0.38
#macro BULB_WATERFALL_SFX_REVERB_MIX         0.42
#macro BULB_WATERFALL_SFX_ECHO_TIME          0.2
#macro BULB_WATERFALL_SFX_ECHO_FEEDBACK      0.26
#macro BULB_WATERFALL_SFX_ECHO_MIX           0.22

// Pond — tile 23 markers on Tiles_Pond (flooded chamber: surface line + depth body).
#macro BULB_POND_ENABLED                     true
#macro BULB_POND_LAYER                       "Tiles_Pond"
#macro BULB_POND_TILE                        23
#macro BULB_POND_BODY_ALPHA                  0.58
#macro BULB_POND_DEEP_ALPHA                  0.72
#macro BULB_POND_SURFACE_ALPHA               0.95
#macro BULB_POND_SURFACE_AMP                 2
#macro BULB_POND_SURFACE_SCROLL              0.55
#macro BULB_POND_SURFACE_WAVE                1
#macro BULB_POND_SURFACE_DOT_ENABLED         true
#macro BULB_POND_SURFACE_DOT_DENSITY         0.09
#macro BULB_POND_SURFACE_DOT_ALPHA           0.9
#macro BULB_POND_SURFACE_DOT_MAX             64
// Horizontal fade at the pond's left/right ends so the tile bounding box doesn't read
// as a hard rectangular cut. 0 disables.
#macro BULB_POND_EDGE_FADE                   14
// Surface physics — 1D spring chain along the waterline, disturbed by the player.
// SPREAD must stay under 0.5 or the propagation diverges.
#macro BULB_POND_WAVE_ENABLED                true
#macro BULB_POND_WAVE_STEP                   3
#macro BULB_POND_WAVE_STIFFNESS              0.022
#macro BULB_POND_WAVE_SPREAD                 0.28
#macro BULB_POND_WAVE_DAMPING                0.965
#macro BULB_POND_WAVE_MAX_PX                 8
#macro BULB_POND_WAVE_LAND_SCALE             0.42
#macro BULB_POND_WAVE_LAND_MAX               7
#macro BULB_POND_WAVE_LAND_RADIUS            14
#macro BULB_POND_WAVE_WADE_SCALE             0.10
#macro BULB_POND_WAVE_WADE_RADIUS            7
#macro BULB_POND_WAVE_EXIT_SCALE             0.22
// Vertices along the waterline are emitted every N pixels. 1 is per-pixel (most detail,
// most CPU); 2-4 barely changes the look since wave nodes are 3px apart anyway.
#macro BULB_POND_SURFACE_COLUMN_STEP         2
// Prints pond draw time (microseconds) and draws-per-frame to the HUD.
#macro BULB_POND_DEBUG_PERF                  false
#macro BULB_POND_CAUSTIC_ENABLED             false
#macro BULB_POND_CAUSTIC_ALPHA               0.22
#macro BULB_POND_CAUSTIC_COUNT               5
#macro BULB_POND_SPARKLE_ENABLED             true
#macro BULB_POND_SPARKLE_DENSITY             0.008
#macro BULB_POND_SPARKLE_ALPHA               0.55
#macro BULB_POND_SPARKLE_SCROLL              0.35
#macro BULB_POND_SPARKLE_MAX                 100
// Overlap into adjacent lay_collision wall cells; walls draw in front and mask the solid art.
#macro BULB_POND_WALL_BLEED                  0
#macro BULB_POND_WALL_SNAP_MAX               32
#macro BULB_WATERFALL_POND_SNAP              96

// Ceiling stalactite drips — spawned from Tiles_Ceiling_Drips, splash on lay_collision.
#macro BULB_CEILING_DRIP_ENABLED             true
#macro BULB_CEILING_DRIP_LAYER               "Tiles_Ceiling_Drips"
#macro BULB_CEILING_DRIP_SPAWN_Y_FRAC        0.92
#macro BULB_CEILING_DRIP_INTERVAL_MIN        110
#macro BULB_CEILING_DRIP_INTERVAL_MAX        300
#macro BULB_CEILING_DRIP_MAX_ACTIVE          40
#macro BULB_CEILING_DRIP_MAX_SPLASH          20
#macro BULB_CEILING_DRIP_FALL_SPEED          2.85
#macro BULB_CEILING_DRIP_MAX_FALL            720
#macro BULB_CEILING_DRIP_FLOOR_STEP           2
#macro BULB_CEILING_DRIP_X_JITTER            3
#macro BULB_CEILING_DRIP_VIEW_PAD            96
#macro BULB_CEILING_DRIP_ALPHA               0.78
#macro BULB_CEILING_DRIP_TIP_ALPHA           0.95
#macro BULB_CEILING_DRIP_STREAK_MIN          5
#macro BULB_CEILING_DRIP_STREAK_MAX          12
#macro BULB_CEILING_DRIP_STREAK_VY_MUL       3.2
#macro BULB_CEILING_DRIP_SPLASH_ALPHA        0.7
#macro BULB_CEILING_DRIP_SPLASH_FRAME_LEN    4

// Drip splash SFX — quiet cave ambience; plays when splash is in camera view.
#macro BULB_CEILING_DRIP_SFX_ENABLED         true
#macro BULB_CEILING_DRIP_SFX_VIEW_PAD         32
#macro BULB_CEILING_DRIP_SFX_HEAR_RADIUS     200
#macro BULB_CEILING_DRIP_SFX_PITCH_MIN        0.62
#macro BULB_CEILING_DRIP_SFX_PITCH_MAX        0.88
#macro BULB_CEILING_DRIP_SFX_PITCH_JITTER     0.05
#macro BULB_CEILING_DRIP_SFX_PITCH_CAVE       0.84
#macro BULB_CEILING_DRIP_SFX_VOL_MIN          0.22
#macro BULB_CEILING_DRIP_SFX_VOL_MAX          0.58
#macro BULB_CEILING_DRIP_SFX_VIEW_VOL         0.42
#macro BULB_CEILING_DRIP_SFX_AUDIO_PRIORITY   5
#macro BULB_CEILING_DRIP_SFX_COOLDOWN         6

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