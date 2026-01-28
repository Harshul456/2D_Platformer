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

// --- COLLISION DISTANCES ---
GROUND_CHECK_DIST = 1;          // Distance to check for grounded state
LANDING_ANIM_DIST = 3;          // Distance to trigger landing animation
WALL_CHECK_OFFSET = 4;          // Head collision offset for wall checks
side_dist = 13;                 // Horizontal collision sensor distance

// --- MOMENTUM PHYSICS ---
MOMENTUM_DECAY_NORMAL = 0.01;   // Air momentum decay rate (straight)
MOMENTUM_DECAY_TURNING = 0.1;   // Air momentum decay when reversing direction
MOMENTUM_CUTOFF = 0.5;          // Stop momentum completely when below this value

// --- DASH MECHANICS ---
dash_timer       = 0;           // Current frame of dash
dash_duration   = 12;           // Total length of dash in frames
dash_speed      = 10;           // Burst velocity during dash
dash_cooldown   = 0;            // Frames until next dash available

// --- COMBAT & DAMAGE ---
obj_player_health = 100;
stomp_force     = 20;           // Downward force for air-stomp
attack_timer    = 0;            // Active frames of attack
attackCooldown  = 20;           // Wait time between attacks
attackCooldownTimer = 0;

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
stunTimer       = 0;

// --- VISUALS ---
image_base_scale = 1;           // Universal scale for character
image_xscale     = image_base_scale;
image_yscale     = image_base_scale;
image_alpha      = 1;
hair_flicker_counter = 0;       // Counter for hair animation flicker

// --- CAMERA SETTINGS ---
cam             = view_camera[0];
cam_w           = 640;
cam_h           = 360;
cam_deadzone_w  = 64;           // The "window" width
cam_deadzone_h  = 32;           // The "window" height
cam_lerp_spd    = 0.15;         // Smoothness
cam_look_ahead  = 0;            // Current horizontal offset
camera_anchor_x = x;
camera_anchor_y = y;

// --- REFLECTION SURFACES ---
surf_reflection = -1;           // Main reflection surface
surf_temp_reflection = -1;      // Temporary reflection drawing surface
max_reflection_size = 128;      // Max size needed (adjust based on largest sprite)