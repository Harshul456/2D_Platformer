// @description obj_enemy — tilemap + grounded defaults from obj_enemy_parent; then legacy threat/AI vars.
event_inherited();

// Start patrolling until the player is actually reachable (prevents wall-hug chase)
state = STATE_PATROL;

obj_enemy_health = 100;
moveSpeed = 1;
chaseRange = 500;
// Horizontal gap before chase halts: half-widths + this (px). Raise for a looser standoff.
chase_stop_extra = 25;
attackRange = 30;

// For Knockback/stun
stunTimer = 0;
hit_blink_timer = 0;
knockbackX = 0;

// Physics
hsp = 0;
vsp = 0;
grv = 0.5;

// Remember the scale from the Room Editor
base_xscale = image_xscale; 
base_yscale = image_yscale;
knockback_pending_x = 0;
knockback_pending_y = 0;
knockback_pending_lift = false;
FINISHER_LIFT_OFFSET = 4;  // Pixels to lift enemy on finisher hit (before applying vsp)

// Escalating knockback: hits within a window stack a multiplier (tuned from player Create constants)
hit_pressure_hits = 0;
hit_pressure_timer = 0;

// --- Melee attack: 0 = red telegraph (still), 1 = dash, 2 = recovery ---
attack_phase = 0;
attack_phase_timer = 0;
attack_hit_dealt = false;
dash_sweep_prev_x = x;
attack_cooldown = 0;
attack_cooldown_max_frames = 52;
enemy_attack_windup_frames = 12;    // Shorter wind-up vs mash (tune with armor frames)
enemy_attack_dash_frames = 16;      // Rush toward player; hit only if AABBs overlap (no phantom reach)
enemy_attack_dash_hsp = 4.1;
enemy_attack_recovery_frames = 18;
attack_commit_band = 0;             // Melee band = half-widths + chase_stop_extra only (spec spatial gate)
enemy_attack_windup_armor_last_frames = 5;   // Last N frames of red wind-up: damage, no hitstun cancel
enemy_attack_dash_super_armor_frames = 10;  // First N frames of dash: damage, no hitstun cancel
enemy_threat_zone_blend = make_color_rgb(110, 160, 255); // in threat band (CHASE/AGGRESSIVE) + reaction/neutral
enemy_threat_retreat_blend = make_color_rgb(170, 210, 255); // defensive retreat (lighter than zone)
retreat_intended_hsp = 0;
retreat_wall_stall = 0;
enemy_retreat_cornered_stall_frames = 2; // wanted retreat hsp but blocked → snap to attack
// Threat pipeline: Melee band + LoS + DCD==0 → THREAT_REACTION → (20% THREAT_NEUTRAL) → branch roll
enemy_threat_reaction_min = 8;      // jittered reaction "processing" (~10f mean @60fps)
enemy_threat_reaction_max = 12;
enemy_threat_neutral_chance = 0.20; // Stage 2: standoff before branch roll
enemy_threat_neutral_min = 50;
enemy_threat_neutral_max = 70;
threat_reaction_timer = 0;
threat_neutral_timer = 0;
threat_neutral_is_exhaustion = false;
// Post-commit: no new threat roll pipeline until 0 (after attack recovery / retreat / forced breath)
enemy_decision_cooldown_min = 30;
enemy_decision_cooldown_max = 60;
enemy_decision_cooldown_move_scale = 0.38; // CHASE/AGGRESSIVE hsp scale while decision_cooldown > 0
decision_cooldown_timer = 0;
// After this many committed actions, forced exhaustion neutral (~100f)
enemy_threat_commit_exhaust_at = 3;
enemy_exhaustion_neutral_min = 96;
enemy_exhaustion_neutral_max = 104;
threat_commit_count = 0;
last_branch_was_retreat = false;
threat_next_roll_retreat_bias = false; // set when player hits enemy out of bait/reaction/retreat/neutral
enemy_interrupt_decision_cooldown_frames = 90; // long slow-approach after bullying a decision state
enemy_bias_scared_aggressive = 0.15;  // interrupt roll: A / patient slice / retreat (cumulative split in script)
enemy_bias_scared_patient_cumulative = 0.40; // random below → patient; above → retreat
// Momentum: many hits in a window → next roll favors spacing (lower patient cap)
pressure_hit_count = 0;
pressure_window_timer = 0;
enemy_pressure_window_frames = 300;   // 5s @60fps
enemy_pressure_hits_threshold = 3;
enemy_pressure_retreat_patient_pull = 0.12;
enemy_retreat_repeat_patient_shift = 0.12; // after retreat, raise patient cap → less repeat retreat
// Stage 3 branch roll (normalized): Aggressive 25% | Patient 45% | Retreat 30%
enemy_patient_wait_min = 20;
enemy_patient_wait_max = 45;
enemy_branch_aggressive = 0.25;
enemy_branch_patient_prob = 0.45;
enemy_branch_retreat_prob = 0.30;
enemy_branch_proximity_px = 15;           // |dx| below → +20% A & R vs patient (scaled)
enemy_branch_rush_hsp_threshold = 2.75;   // |hsp| above + moving toward enemy → pressure scaling
enemy_branch_away_hsp_threshold = 0.4;  // moving away → retreat weight 0
enemy_branch_pressure_weight_mult = 1.2;  // multiply A and R before renormalize
enemy_retreat_min_px = 18;
enemy_defensive_retreat_frames = 22; // floor; actual timer = max(this, ceil(min_px/hsp))
enemy_defensive_retreat_hsp = 2.6;
enemy_defensive_post_cooldown = 28;
patient_wait_timer = 0;
retreat_timer = 0;
was_in_attack_threat_zone = false;
enemy_attack_damage = 12;
// --- Patrol (spawn leash when not chasing) ---
spawn_x = x;
patrol_range_px = 180;
patrol_speed = 0.55;
patrol_dir = (random(1) < 0.5) ? -1 : 1;
patrol_pause_timer = irandom_range(8, 35);
patrol_edge_pause_min = 18;
patrol_edge_pause_max = 48;
// Give up chasing when LoS or walk channel fails for this many frames
enemy_chase_path_blocked_frames = 40;
chase_path_blocked_timer = 0;
enemy_attack_hsp_push = 4.8;

// Post-stun aggression (after player hitstun ends) (after player hitstun ends)
aggressive_timer = 0;
aggressive_timer_max = 48;
last_hit_was_finisher = false;    // Set from player combo hit 2
retaliation_range_x = 110;        // After finisher stun + still this close: extra aggressive_timer + scared next roll

// Telegraph draw offset (set in scr_enemy_ai during windup)
telegraph_shake_x = 0;
telegraph_shake_y = 0;
