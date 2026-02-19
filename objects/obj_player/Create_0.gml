// --- STATUS & STATE ---
is_dying        = false;        // Trigger for pit death/abyss fall
can_move        = true;         // Control toggle for input
attacking       = false;        // State for combat lockout
grounded        = false;        // Track floor contact
is_dashing      = false;        // Dash state toggle

// --- RESPONSIVENESS BUFFERS ---
coyote_time_max = 6;            // Grace period frames for late jumps
coyote_time_timer = 0;          // Countdown
jump_buffer_max = 5;            // Frames to "remember" a jump press
jump_buffer_timer = 0;          // Countdown
attack_buffer_max = 5;          // Frames to "remember" an attack press
attack_buffer_timer = 0;        // Countdown

// --- MOVEMENT SETTINGS ---
hsp             = 0;            // Horizontal velocity
vsp             = 0;            // Vertical velocity
grv             = 0.5;          // Gravity strength
walksp          = 3.5;          // Standard walk speed
runsp           = 5.0;          // Fast walk/run speed
jumpsp          = 9.0;          // Jump power
jump_count      = 0;            // Double jump tracker
last_direction  = 1;            // Facing: 1 = Right, -1 = Left
runMomentum     = 0;            // Stores speed for air-carry

// --- ANIMATION THRESHOLDS ---
JUMP_RISE_THRESHOLD = -1;       // vsp threshold for rising animation
JUMP_PEAK_MIN = -1;             // vsp range for peak animation start
JUMP_PEAK_MAX = 1;              // vsp range for peak animation end
MOVEMENT_THRESHOLD = 0.5;       // hsp threshold to trigger run animation
ANIM_LAND_CROUCH_START = 8;     // Jump sprite: first frame of landing crouch (8–10)
ANIM_LAND_CROUCH_END = 10;      // Jump sprite: last frame of landing crouch (then go idle)
ANIM_HAIR_FLICKER_INTERVAL = 5; // Frames between hair flicker (falling) frame switch
ANIM_HAIR_FLICKER_THRESHOLD = 2.5; // Which half of interval for frame 5 vs 6
ANIM_DASH_LOOP_END = 5.9;       // Dash sprite: loop frames 0–5, then reset
ANIM_DASH_REEL_START = 6;       // Dash sprite: reel-back starts at frame 6
ANIM_DASH_REEL_END = 8.8;       // Dash sprite: after frame 8 complete, go idle

// --- COLLISION DISTANCES ---
GROUND_CHECK_DIST = 1;          // Distance to check for grounded state
LANDING_ANIM_DIST = 3;          // Distance to trigger landing animation
WALL_CHECK_OFFSET = 4;          // Head collision offset for wall checks
LEDGE_STEP_MAX = 2;             // Max pixels to step up when blocked by small ledge (1–2px lip)
LEDGE_TOE_INSET = 2;            // Vertical inset for toe when checking horizontal clearance (feet_y - this)
// NOTE: Collision sampling derives from bbox_* inside scr_player_movement().

// --- MOMENTUM PHYSICS ---
MOMENTUM_DECAY_NORMAL = 0.01;   // Air momentum decay rate (straight)
MOMENTUM_DECAY_TURNING = 0.1;   // Air momentum decay when reversing direction
MOMENTUM_CUTOFF = 0.5;          // Stop momentum completely when below this value

// --- DASH MECHANICS ---
dash_timer       = 0;           // Current frame of dash
dash_duration   = 12;           // Total length of dash in frames
dash_speed      = 10;           // Burst velocity during dash
dash_cooldown   = 0;            // Frames until next dash available
dash_cooldown_extra = 8;        // Extra frames added to cooldown after dash (dash_cooldown = dash_duration + this)
dash_afterimage_interval = 4;   // Create afterimage every N frames during dash

// --- WALL JUMP / WALL CLING (Mario, Sonic, Mega Man style) ---
wall_side             = 0;     // -1 = clinging left wall, 1 = right, 0 = none
wall_slide_speed      = 0.4;    // Max downward speed while clinging (slow slide)
wall_jump_hsp         = 5;     // Horizontal push away from wall on jump
wall_jump_lock        = 0;     // Frames after wall jump where we can't re-stick
wall_jump_lock_frames  = 15;   // Value set when we wall jump (duration of lock + direction lock)
wall_jump_extend_time  = 6;    // Frames to show "extend" sprite (frame 1) after push-off
wall_jump_extend_timer = 0;    // Countdown for extend animation
wall_cling_grace       = 0;    // Frames to keep wall_side after detection (stops flicker)
wall_cling_grace_frames = 8;   // Value set when we detect wall (keeps cling from flickering at edges)
wall_cling_frames      = 0;    // Frames spent clinging (reset on land/leave wall; for future use)
wall_cling_vsp_min     = -1;   // Only cling at apex or falling (vsp >= this); rising = full jump anim
wall_jump_last_side    = 0;    // -1/1 = wall we last jumped from; 0 = none (allows side-to-side, blocks same wall)

// --- COMBAT & DAMAGE ---
obj_player_health = 100;
stomp_force     = 20;           // Downward force for air-stomp
attack_timer    = 0;            // Active frames of attack
attackCooldown  = 20;           // Wait time between attacks
attackCooldownTimer = 0;

// Attack hitbox and lunge (tuning in one place)
ATTACK_REACH_FACTOR   = 0.42;   // Reach = max(ATTACK_REACH_MIN, bbox_w * this)
ATTACK_REACH_MIN      = 16;     // Minimum attack reach in pixels
ATTACK_HITBOX_PAD_Y   = 4;      // Vertical padding for attack hitbox
ATTACK_LUNGE_FRICTION = 0.35;   // Friction during attack lunge (lerp toward 0)
ATTACK_LUNGE_CUTOFF   = 0.3;    // Zero hsp when below this
ATTACK_ON_HIT_HSLOW   = 0.5;    // Multiply hsp when attack hits (stop sliding through)
ATTACK_ON_HIT_PUSHBACK = 0.5;   // Player pushback on hit (prevent overlap)

// Damage/knockback when player is hit by enemy (Collision_obj_enemy)
ENEMY_COLLISION_DAMAGE  = 10;   // Health lost per touch
ENEMY_KNOCKBACK_X       = 4;    // Horizontal knockback
ENEMY_KNOCKBACK_Y       = -3;   // Vertical knockback (up)
ENEMY_STUN_FRAMES       = 15;   // Frames player is stunned
INVINCIBILITY_FRAMES    = 90;   // Frames of invincibility after hit
COLLISION_SEPARATION_PUSH = 1.5; // Push player out of enemy when overlapping

// Damage/knockback when player hits enemy (Step_0 attack block)
ATTACK_DAMAGE_PER_HIT   = 20;   // Damage per swing
ATTACK_HIT_BLINK_FRAMES = 20;   // Enemy blink duration
ATTACK_STUN_FRAMES      = 30;   // Enemy stun duration
ATTACK_LIGHT_KNOCKBACK  = 1.5;  // Light hit horizontal
ATTACK_LIGHT_HITSTOP    = 3;    // Light hit freeze frames
ATTACK_FINISHER_KNOCKBACK_X = 6;  // Finisher horizontal
ATTACK_FINISHER_KNOCKBACK_Y = -6; // Finisher vertical (launch)
ATTACK_FINISHER_HITSTOP = 8;    // Finisher freeze frames

// --- COMBO SYSTEM ---
comboCount      = 0;
comboTimer      = 0;
comboCooldown   = 40;
combo_buffer    = false;        // Did the player click while already swinging?
attack_has_hit  = false;        // Prevent multi-hits on one swing
hitstop_timer   = 0;            // For that "weighty" feel

// --- INVINCIBILITY & FEEDBACK ---
invincible      = false;
invincibleTimer = 0;
blinkDelay      = 5;
blinkCounter    = 0;
knockBackX      = 0;
knockBackY      = 0;
knockback_friction = 0.9;       // Per-frame decay of knockback (multiply)
stunTimer       = 0;
jump_cut_multiplier = 0.333;    // Release jump early: cap rise speed to jumpsp * this (short hop)

// --- VISUALS ---
image_base_scale = 1;           // Universal scale for character
image_xscale     = image_base_scale;
image_yscale     = image_base_scale;
image_alpha      = 1;
hair_flicker_counter = 0;       // Counter for hair animation flicker
force_landing_crouch  = false;   // When landing from wall: play full crouch even if holding a direction

// --- REFLECTION ---
reflection_timer = 0;
reflection_timer_max = 20;      // Frames to fade reflection when jumping away
REFLECT_BAND_HEIGHT = 4;        // Vertical band height for reflection draw (smaller = smoother clip edge)
REFLECT_FADE_DIST = 56;         // Pixels below feet until reflection fades out (vertical)
REFLECT_FADE_X = 36;            // Horizontal pixels until fully faded at sides (diagonal falloff)
REFLECT_DIAG_STRENGTH = 0.9;    // How much horizontal falloff affects fade (0..1.5)
REFLECT_PLATFORM_SCAN_MAX = 64; // Max pixels to scan down for platform bottom (2 tiles; prevents infinite loop)

// Reflection region (art-directed mirror strip).
// X bounds control horizontal reflective area (set per-room if you want specific platforms only).
// Y is now dynamic - reflection works on any platform when grounded.
reflect_region_x1 = 0;                  // Left bound of reflective area (0 = entire room)
reflect_region_x2 = room_width;         // Right bound of reflective area (room_width = entire room)
reflect_region_y  = 0;                  // Dynamic - set automatically when on platform