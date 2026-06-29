// Player input — keyboard + first connected gamepad (Switch Pro / paired Joy-Cons on PC).
// Switch face layout: A=jump, ZR=sprint, X=attack, L/ZL=wall cling. Left stick + D-pad = move.

#macro GP_MOVE_DEADZONE       0.35
#macro GP_BTN_JUMP            gp_face1   // Switch A (bottom)
#macro GP_BTN_SPRINT          gp_shoulderrb   // Switch ZR
#macro GP_BTN_ATTACK          gp_face3   // Switch X (left)
#macro GP_BTN_WALL_CLING      gp_shoulderl
#macro GP_BTN_WALL_CLING_ALT  gp_shoulderlb

/// @returns {Real} First connected gamepad slot (0..7), or -1.
function scr_player_input_find_slot() {
    static _last_slot = -1;
    if (_last_slot >= 0 && gamepad_is_connected(_last_slot)) {
        return _last_slot;
    }
    for (var _i = 0; _i < 8; _i++) {
        if (gamepad_is_connected(_i)) {
            _last_slot = _i;
            return _i;
        }
    }
    _last_slot = -1;
    return -1;
}

/// @description Poll keyboard and gamepad into obj_player key_* fields (call on player instance).
function scr_player_input_poll() {
    key_left           = keyboard_check(vk_left);
    key_right          = keyboard_check(vk_right);
    key_jump           = keyboard_check_pressed(vk_up);
    key_jump_held      = keyboard_check(vk_up);
    key_down           = keyboard_check(vk_down);
    key_sprint         = keyboard_check(ord("Z"));
    key_sprint_press   = keyboard_check_pressed(ord("Z"));
    key_attack         = keyboard_check_pressed(ord("X"));
    key_wall_cling     = keyboard_check(vk_lshift) || keyboard_check(vk_rshift);

    var _gp = scr_player_input_find_slot();
    global.player_gamepad_slot = _gp;
    if (_gp < 0) return;

    gamepad_set_axis_deadzone(_gp, GP_MOVE_DEADZONE);

    if (gamepad_button_check(_gp, gp_padl)) key_left  = true;
    if (gamepad_button_check(_gp, gp_padr)) key_right = true;
    if (gamepad_button_check(_gp, gp_padd)) key_down  = true;

    var _axis_h = gamepad_axis_value(_gp, gp_axislh);
    var _axis_v = gamepad_axis_value(_gp, gp_axislv);
    if (_axis_h <= -GP_MOVE_DEADZONE) key_left  = true;
    if (_axis_h >= GP_MOVE_DEADZONE)  key_right = true;
    if (_axis_v >= GP_MOVE_DEADZONE)  key_down  = true;

    if (gamepad_button_check_pressed(_gp, GP_BTN_JUMP))   key_jump = true;
    if (gamepad_button_check(_gp, GP_BTN_JUMP))           key_jump_held = true;

    if (gamepad_button_check(_gp, GP_BTN_SPRINT))         key_sprint = true;
    if (gamepad_button_check_pressed(_gp, GP_BTN_SPRINT)) key_sprint_press = true;

    if (gamepad_button_check_pressed(_gp, GP_BTN_ATTACK)) key_attack = true;

    if (gamepad_button_check(_gp, GP_BTN_WALL_CLING)
        || gamepad_button_check(_gp, GP_BTN_WALL_CLING_ALT)) {
        key_wall_cling = true;
    }
}
