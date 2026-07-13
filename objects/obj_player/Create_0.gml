// --- STATUS & STATE ---
is_dying        = false;        // Trigger for pit death/abyss fall
can_move        = true;         // Control toggle for input
attacking       = false;        // State for combat lockout
grounded        = false;        // Track floor contact
is_sprinting    = false;        // Hold Z on ground while moving

// --- RESPONSIVENESS BUFFERS ---
coyote_time_max = 6;            // Grace period frames for late jumps
coyote_time_timer = 0;          // Countdown
jump_buffer_max = 11;           // Frames to "remember" a jump press (wall cling + late wall jump; see §2c slide pause)
jump_buffer_timer = 0;          // Countdown
attack_buffer_max = 12;         // Frames to "remember" an attack press (idle only — not refilled while swinging)
attack_buffer_timer = 0;        // Countdown
attack_chain_buffer_max = 8;    // Legacy decay timer (kept for debug); chain uses attack_chain_latched
attack_chain_buffer_timer = 0;
attack_chain_latched = false;   // Any X press during swing 1 queues 1→2 (survives mash at start of swing)

// --- MOVEMENT SETTINGS ---
hsp             = 0;            // velocity
vsp             = 0;            // Vertical velocity
grv             = 0.5;          // Gravity strength
walksp          = 3.5;          // Standard walk speed
runsp           = 5.0;          // Sprint speed (hold Z; slightly above walksp)
jumpsp          = 9.0;          // Jump power
jump_count      = 0;            // 0 = fresh from ground; 1 = one air jump left; 2 = no jumps until land (incl. after wall jump / walk-off).
jumped_this_frame = false;      // Set true in scr_player_movement when a jump fires (footsteps land check reads this).
// True after spending the second air jump (or walk-off single-jump mode). Cleared on land. Wall jump sets both this and jump_count=2.
air_chain_jump_used = false;
last_direction  = 1;            // Facing: 1 = Right, -1 = Left
runMomentum     = 0;            // Stores speed for air-carry
post_attack_accel_timer = 0;    // Ramp walk speed after heavy attack land

// --- ANIMATION THRESHOLDS ---
JUMP_RISE_THRESHOLD = -1;       // vsp threshold for rising animation
JUMP_PEAK_MIN = -1;             // vsp range for peak animation start
JUMP_PEAK_MAX = 1;              // vsp range for peak animation end
MOVEMENT_THRESHOLD = 0.5;       // hsp threshold to trigger run animation

// Cave footsteps (snd_cave_footstep1–3) — animation contact frames on spr_mc_jog / spr_mc_sprint.
FOOTSTEP_CAVE_ENABLED = true;
FOOTSTEP_JOG_CONTACT_FRAMES = [2, 6];     // Tune to match foot-down frames in jog cycle
FOOTSTEP_SPRINT_CONTACT_FRAMES = [2, 6];
FOOTSTEP_PITCH_MIN = 0.88;
FOOTSTEP_PITCH_MAX = 1.12;
FOOTSTEP_PITCH_JITTER = 0.04;
FOOTSTEP_VOL_MIN = 0.55;
FOOTSTEP_VOL_MAX = 0.9;
FOOTSTEP_MIN_INTERVAL = 4;                // Frames between steps (anti-double-trigger safety)
FOOTSTEP_AUDIO_PRIORITY = 8;
// Landing thud — assign snd_cave_land when you import a dedicated land clip.
FOOTSTEP_LAND_SOUND = snd_cave_footstep1;
FOOTSTEP_LAND_PITCH_MIN = 0.72;
FOOTSTEP_LAND_PITCH_MAX = 0.95;
FOOTSTEP_LAND_VOL_MIN = 0.65;
FOOTSTEP_LAND_VOL_MAX = 1.0;
LAND_SOUND_MIN_VSP = 2.5;                 // Ignore micro-grounding blips / tiny falls
LAND_SOUND_VSP_REF = 8;                   // Fall speed that plays a full-impact land
LAND_SOUND_MIN_AIR_FRAMES = 4;            // Must be airborne this many frames before land SFX
FOOTSTEP_LAND_STEP_COOLDOWN = 8;          // Block jog step right after land thud
FOOTSTEP_REELBACK_CONTACT_FRAMES = [1, 2]; // Skid frames in spr_mc_reelback (3-frame cycle)
// Ground debris — purple kick-up at feet (walk, run, reel-back, land).
GROUND_DEBRIS_ENABLED = true;
GROUND_DEBRIS_MAX = 80;
GROUND_DEBRIS_GRAVITY = 0.2;
GROUND_DEBRIS_DRAG = 0.9;
GROUND_DEBRIS_COLORS = [
    make_color_rgb(94, 74, 102),   // #5E4A66 — ground mid-tone
    make_color_rgb(74, 59, 82),    // #4A3B52 — ground base
    make_color_rgb(46, 36, 51),    // #2E2433 — ground shadow
    make_color_rgb(125, 101, 133)  // #7D6585 — tile edge highlight
];
ground_debris_list = [];
footstep_anim_prev_index = 0;
footstep_last_clip = -1;
footstep_cooldown = 0;
footstep_track_sprite = -1;
footstep_was_grounded = true;
footstep_fall_vsp = 0;
footstep_airborne_frames = 0;

ANIM_LAND_CROUCH_START = 8;     // Jump sprite: first frame of landing crouch (8–10)
ANIM_LAND_CROUCH_END = 10;      // Jump sprite: last frame of landing crouch (then go idle)
ANIM_HAIR_FLICKER_INTERVAL = 5; // Frames between hair flicker (falling) frame switch
ANIM_HAIR_FLICKER_THRESHOLD = 2.5; // Which half of interval for frame 5 vs 6
ANIM_JOG_FRAME_COUNT = 7;       // spr_mc_jog subimages

// --- COLLISION DISTANCES ---
GROUND_CHECK_DIST = 1;          // Distance to check for grounded state (probe below bbox bottom)
GROUND_PROBE_EDGE_INSET = 12;   // Inset L/R floor probes on full floors (cap tiles use bbox L/R)
AIR_FALL_EDGE_INSET = 18;       // Inset used for airborne falling probes (prevents toe-hover when stepping off edges)
GROUND_STANDABLE_EMBED_PX = 10;
GROUND_LAND_VOTES_MIN_AIR = 2;
// Thin shelf caps: bbox center can sit over empty half of the 32px cell while both feet still hit solid.
// Allow grounded when floor votes pass and probe hits stay within this many tile columns (blocks abyss bridges).
CAP_GROUND_CELL_SPAN_MAX = 1;
// Full TILECOL_SHAPE_FULL blocks: Mega Man–style lip — allow grounded when inset stand votes pass even if center probe misses void (see 6c + anchor).
FULL_BLOCK_EDGE_GROUND_FORGIVE = true;
// Full block: if feet row local Y >= this, treat as sunk into tile (pop up / no lip-teeter).
FULL_BLOCK_FEET_INTERIOR_LY_MIN = 2;
// Air peel: treat overlap with only the top N rows of a full block like thin-cap peel (no y-- pop off the lip).
FULL_BLOCK_TOP_PEEL_BAND_PX = 4;
// When toes still hug a full-block lip, keep stable ground visuals in air anim / teeter (avoids flicker if grounded hiccups).
FULL_BLOCK_LIP_ANIM_STICKY_HOLD_FRAMES = 12;
full_lip_anim_sticky = 0;
// Consecutive frames with center under feet before clearing lip sticky (stops 1-frame center flicker from wiping sticky).
FULL_BLOCK_LIP_STICKY_CLEAR_CENTER_FRAMES = 4;
full_lip_center_stable_frames = 0;
// After §2 clears grounded on a full-block lip, re-ground for this many Steps while probes still see floor (blink).
GROUND_LIP_GROUND_BLESS_MAX = 10;
lip_ground_bless = 0;
// §2: consecutive Steps with no floor signal at lip before allowing grounded=false (kills 1-frame probe flicker).
GROUND_LIP_S2_AIR_STREAK_TO_CLEAR = 2;
lip_s2_edge_air_streak = 0;
// On thin shelves, one toe on the lip often fails the 2-of-3 stand vote; still treat as standing when |vsp| is small.
SHELF_STAND_VSP_ABS_MAX = 3;
// When tile index 1 shelf is under feet, single-toe relax uses this smaller |vsp| cap (stricter than other shelves).
SHELF_STAND_VSP_TILE1 = 1.15;
TILEMAP_AIR_SEPARATION_MAX = 6;
GROUND_SNAP_MAX = 4;
GROUND_SNAP_PROBE_DEPTH = 6;
GROUND_SNAP_POST_ANIM_MAX = 10;
GROUND_SNAP_THIN_CAP_MAX = 1;
GROUND_SNAP_POST_THIN_CAP_MAX = 2;
LANDING_ANIM_DIST = 3;          // Distance to trigger landing animation
WALL_CHECK_OFFSET = 4;          // Head sample for horizontal ledge / corner probes
// Wall slide / wall jump (MMX-style: jumpable_wall_dir + wall_slide / wall_jump states)
// Probes sit on the collision mask edge (MMX uses origin ±9; we use mask ±1). Optional scrape = !can_move_x(move) analogue.
WALL_FACE_PROBE_OUTSET = 1;     // Pixels outside bbox_left / bbox_right for wall column samples
WALL_CONTACT_HOLD_BIAS_PX = 3;  // With Shift: nudge wall probes on pressed side; Shift alone nudges both sides outward (single-wall contact).
WALL_JUMP_PROXIMITY_PX = 6;     // Horizontal scan from bbox edge: defer air jump if solid this close (post–H wall jump)
WALL_BODY_HI_FROM_HEAD = 14;    // Upper-body sample Y = head_y + this (reject ledge: feet-only hits)
WALL_CONTACT_MIN_SAMPLES = 2;   // Need this many hits among [low, mid, high] on the wall column
// Wall cling also requires the feet-band probe to hit (rejects top-tile-only corners that look like a bad cling).
WALL_CLING_REQUIRE_FEET_BAND = true;
// If true: cannot cling on the top tile of a wall — requires solid one tile height above the top wall hit on the face column.
WALL_CLING_BLOCK_TOP_TILE = true;
// If true: cannot cling on the bottom tile of a wall — requires solid one tile height below the lowest wall hit. Turn off if it fights floors / short walls.
WALL_CLING_BLOCK_BOTTOM_TILE = true;
// MMX-style: while holding Shift to cling, require a solid hit 1px past the bbox face (like !can_move_x(move)); rejects false clings.
WALL_REQUIRE_SCRAPE_MOTION = true;
// When clinging with Shift only (no L/R): scan this many pixels past bbox for scrape — fixes 1–2px air gap vs strict bbox+1 check.
WALL_SCRAPE_DEPTH_NEUTRAL_CLING_PX = 8;
WALL_SLIDE_VSP = 2;             // Max downward speed while sliding (MMX wall_slide_vspeed)
WALL_JUMP_VSP = 9;              // Upward impulse on wall jump (tune height)
WALL_JUMP_HSP = 6;              // Horizontal: initial push away; also caps enforced-away speed during kick
WALL_JUMP_AWAY_CLAMP_MULT = 0.82; // During wall_kick: at least HSP×this toward away if holding into wall (never above HSP)
WALL_JUMP_MIN_AWAY_HOLD = 0;    // Extra |hsp| floor while kicking (0 = off). Capped at WALL_JUMP_HSP so low HSP works
WALL_JUMP_LOCK_FRAMES = 12;
WALL_JUMP_EXTEND_FRAMES = 10;
WALL_JUMP_CEIL_CLEAR = 6;
// After wall jump: hold spr_mc_walljump subimage 1 (kick-off) this many Steps, then spr_mc_jump while extend_timer runs.
WALL_JUMP_KICK_HOLD_FRAMES = 5;
// Wall jump only when falling into the wall slide (not while rising); lets double jump win beside walls.
WALL_JUMP_MIN_FALL_VSP = 0.15;
// When double jump is still banked (jump_count==1, air_chain false): wall jump needs this min vsp so slow scrapes use air jump.
// -1 = 0.82×WALL_SLIDE_VSP (~1.64 with slide 2); 0 = same threshold as everyone (MIN_FALL only).
WALL_JUMP_MIN_VSP_FOR_DOUBLE_GUARD = -1;
// With Shift at a wall: allow wall jump if downward speed is this close to the fall threshold (apex / guard edge).
WALL_JUMP_FALL_VSP_EPSILON_CLING = 0.31;
// Wall slide + wall jump: hold Shift (L or R) in air for WALL_SHIFT_HOLD_FRAMES_REQUIRED consecutive Steps; arrows alone never cling.
WALL_SHIFT_HOLD_FRAMES_REQUIRED = 14;
WALL_KICK_COOLDOWN_FRAMES = 22; // Cannot re-stick to kicked wall this long (first kick / same face)
// When wall-jumping between two walls: shorter cooldown after leaving the opposite face (narrow shaft zigzag).
WALL_KICK_COOLDOWN_SHAFT_FRAMES = 8;
WALL_CLING_DRAW_NUDGE_PX = 5;   // Draw-only: pull spr_mc_walljump toward wall (mask stays idle)
wall_side = 0;                  // −1 = wall on left, +1 = wall on right
wall_jump_lock = 0;
wall_jump_extend_timer = 0;
wall_jump_kick_hold_timer = 0;
double_jump_anim_active = false; // spr_mc_doublejump after air chain jump
double_jump_anim_tick = 0;     // Steps elapsed in current double-jump sequence
wall_kick_cooldown = 0;         // >0: ignore kicked wall column + enforce away hsp
wall_kick_from_side = 0;       // Wall side we last kicked from (−1 / +1)
wall_shift_hold_timer = 0;     // Consecutive airborne Steps with Shift held; wall cling needs WALL_SHIFT_HOLD_FRAMES_REQUIRED
wall_cling_debris_active = false;
wall_cling_debris_scrape_timer = 0;
WALL_CLING_DEBRIS_SCRAPE_INTERVAL = 8;
LEDGE_STEP_MAX = 2;
LEDGE_TOE_INSET = 2;
HORIZONTAL_LEDGE_WINDOW_PX = 6; // Side collision ignored when bbox_bottom is this close to tile top (mount / corner clip).
PLAYER_STATE_IDLE = 0;
PLAYER_STATE_LAND = 1;
player_movement_state = PLAYER_STATE_IDLE;
SIDE_ENTRY_MIN_VSP = 0.2;       // Passive side-entry: min downward speed (hold toward ledge bypasses vsp + air gates).
SIDE_ENTRY_CATCH_WINDOW_PX = 4; // Vertical window for side-entry only (tighter than horizontal mount window).
SIDE_ENTRY_MIN_AIR_FRAMES = 2;  // Passive side-entry: min consecutive air frames (hold toward ledge bypasses).
side_entry_airborne_frames = 0; // Incremented each airborne Step end; reset when grounded.
POST_ATTACK_ACCEL_FRAMES = 12;
// NOTE: Collision sampling derives from bbox_* inside scr_player_movement().

// --- MOMENTUM PHYSICS ---
MOMENTUM_DECAY_NORMAL = 0.01;   // Air momentum decay rate (straight)
MOMENTUM_DECAY_TURNING = 0.1;   // Air momentum decay when reversing direction
MOMENTUM_CUTOFF = 0.5;          // Stop momentum completely when below this value

// --- SPRINT MECHANICS ---
sprint_afterimage_interval = 4; // Create afterimage every N frames while sprinting
sprint_afterimage_tick = 0;     // Frame counter for sprint afterimages
sprint_jump_carry = false;      // Airborne horizontal speed from sprint jump / sprint run-off
sprint_air_trail = false;       // Afterimages in air after sprint jump until landing
sprint_reel_active = false;     // spr_mc_reelback playing
sprint_reel_pending = false;    // Armed after sprint ends — reel when direction released
sprint_reel_dir_wait = 0;       // Frames to wait for direction to release after Z up before assuming walk intent
SPRINT_REEL_DIR_WAIT_FRAMES = 14; // ~230ms @60fps — forgiving staggered key release when stopping from sprint
sprint_committed = false;       // Active sprint session (tap = burst only; hold Z = burst + sustain)
sprint_hold_latched = false;    // True once Z stays held after first burst frame → sustained runsp
sprint_z_idle_charged = false;  // Z held while standing — next direction press starts sprint
sprint_resume_hold = false;     // Z held through hold-sprint jump — resume sustain on landing
sprint_dir_gap = 0;             // Frames left to keep sprint during direction-key switch gap
SPRINT_DIR_SWITCH_GAP = 6;      // Grace frames when swapping L/R while holding Z
sprint_burst_tick = 0;          // Frames elapsed this commit (1..SPRINT_BURST_FRAMES = burst speed)
sprint_commit_dir = 0;          // Direction locked in when sprint started (−1 / +1)
SPRINT_BURST_FRAMES = 15;       // Tap-Z dash length; hold-Z also uses this before runsp sustain
SPRINT_BURST_SPEED = 8.5;       // Speed during burst phase (hold-Z sustain uses runsp)
SPRINT_JUMP_CARRY_MULT = 1.12;  // Jump/leaving ground while sprinting: runsp × this (initial air hsp)
SPRINT_AIR_DECAY = 0.003;       // Air lerp toward 0 while sprint_jump_carry (lower = longer glide)
SPRINT_AIR_DECAY_TURN = 0.10;   // Extra decay when reversing direction in air during carry
SPRINT_AIR_DECAY_HOLD = 0.001;  // Decay while holding Z + same direction in air (near-zero = coast)
SPRINT_AIR_MIN = 4.25;          // End carry once |hsp| drops below this (between walksp and runsp)

// Sprint activation game-feel (Z press commit in scr_player_movement §4)
SPRINT_SQUASH_COIL_X = 1.2;
SPRINT_SQUASH_COIL_Y = 0.8;
SPRINT_SQUASH_LERP = 0.15;
sprint_squash_x = 1;
sprint_squash_y = 1;
sprint_squash_coil_frames = 0; // Set to 1 on Z press — exactly one Step of coil before normal scale

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
debug_hitbox_x1 = 0; debug_hitbox_y1 = 0; debug_hitbox_x2 = 0; debug_hitbox_y2 = 0; debug_hitbox_active = false;
// When true: yellow HUD (always) + IDE Output lines for airborne + small |vsp| (ledge stall hunt). Off after capture.
DEBUG_LEDGE_AIR_STALL = false;
// Log / HUD when !grounded and |vsp| <= this (0.001 misses float dust; 0.12 catches slow starts without spamming whole fall).
DEBUG_LEDGE_LOG_VSP_MAX = 0.12;
debug_ledge_hunt_announced = false;
ledge_dbg_line = "";
ATTACK_LUNGE_FRICTION = 0.35;   // Friction during attack lunge (lerp toward 0)
ATTACK_LUNGE_CUTOFF   = 0.3;    // Zero hsp when below this
// First subimage with an active hitbox (Step uses >= 1); enemies use this for startup priority / dash contact.
ATTACK_HIT_ACTIVE_START_INDEX = 1;
ATTACK_ON_HIT_HSLOW   = 0.5;    // Multiply hsp when attack hits (stop sliding through)
ATTACK_ON_HIT_PUSHBACK = 2.5;   // Player pushback on hit (prevent overlap)

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
ATTACK_LIGHT_KNOCKBACK  = 5;    // Light hit horizontal (enemy)
ATTACK_LIGHT_HITSTOP    = 5;    // Light hit freeze frames (~83ms @60fps)
ATTACK_FINISHER_KNOCKBACK_X = 6;  // Finisher horizontal
ATTACK_FINISHER_KNOCKBACK_Y = -6; // Finisher vertical (launch)
ATTACK_FINISHER_HITSTOP = 8;    // Finisher freeze frames

// --- ATTACK LUNGE / SHIFT / HITBOX (Step_0 attack block; keep in sync with sprites) ---
attack_priority_timer = 0;    // Startup priority frames (set by attack flow if needed)
attack_no_lunge = false;        // When true: skip shift + combo lunge (e.g. air-locked swings)
attack_shift_remaining = 0;   // Pixels of forward slide queued on attack start
ATTACK_SHIFT_PX_1 = 4;
ATTACK_SHIFT_PX_2 = 5;
ATTACK_SHIFT_PX_PER_FRAME = 1;
ATTACK_COMBO_LUNGE_FRAME_END = 0.42;   // image_index <= image_number * this during lunge window
ATTACK_COMBO_LUNGE_PER_FRAME = 0;      // 0 = off (only scr_player_attack initial hsp + friction; no per-frame drive)
ATTACK_COMBO_LUNGE_MAX_HSP = 5.5;
ATTACK_COMBO_LUNGE_MAX_HSP_2 = 7;
ATTACK_COMBO2_PLAYER_RECOIL = 1.5;
ATTACK_HITBOX_REACH_1 = 28;
ATTACK_HITBOX_REACH_2 = 38;
ATTACK_HITBOX_TOP_PAD_1 = 10;
ATTACK_HITBOX_TOP_PAD_2 = 10;
ATTACK_HITBOX_BOT_PAD_1 = 14;
ATTACK_HITBOX_BOT_PAD_2 = 14;
ATTACK_HITBOX_X_INSET = 4;
ENEMY_HIT_PRESSURE_WINDOW_FRAMES = 45;
HIT_PRESSURE_KB_PER_STACK = 0.08;
HIT_PRESSURE_KB_MULT_CAP = 1.5;
ENEMY_STUN_AFTER_HIT1 = 30;
ENEMY_STUN_AFTER_HIT2 = 40;

// --- COMBO SYSTEM ---
comboCount      = 0;
comboTimer      = 0;
comboCooldown   = 40;
combo_buffer    = false;        // Did the player click while already swinging?
attack_key_released_this_swing = false;  // For 1→2: release-then-press = double-tap (avoids single-hold chain)
attack_has_hit  = false;        // Prevent multi-hits on one swing
hitstop_timer   = 0;            // For that "weighty" feel
ATTACK_RECOVERY_GRACE = 8;      // Frames of protection after attack ends (covers 3rd attack windup)
attack_recovery_grace = 0;      // Countdown; set when attack ends without combo
attack_lockout = 0;             // Blocks new attack from section 2 until current attack finishes

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
force_landing_crouch  = false;   // When true, landing crouch plays fully even if holding a direction

// --- BULB LIGHTING ---
bulb_light = undefined;

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

// Previous frame bbox_bottom for one-way ledge threshold (indices 1,5,34,35,36; see tilemap_shelf_threshold_land_dy).
shelf_bb_bottom_prev = bbox_bottom;
// True for this Step after tilemap_shelf_threshold_land_dy applied a snap (strict 34/36 lip needs 6c grounded).
shelf_threshold_snap_this_step = false;