import Carbon.HIToolbox

enum KeyHand: Equatable {
    case left
    case right
    case neutral
    case unknown
}

enum KeyHandClassifier {
    static func hand(for keyCode: UInt16) -> KeyHand {
        // Carbon virtual key codes identify physical keys, even when layouts relabel them.
        switch Int(keyCode) {
        case kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G,
             kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B,
             kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T,
             kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
             kVK_ANSI_Grave, kVK_Escape, kVK_Tab, kVK_CapsLock,
             kVK_Command, kVK_Shift, kVK_Option, kVK_Control, kVK_ISO_Section,
             kVK_JIS_Eisu, kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5:
            return .left

        case kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
             kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
             kVK_ANSI_N, kVK_ANSI_M,
             kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0,
             kVK_ANSI_Minus, kVK_ANSI_Equal, kVK_ANSI_LeftBracket,
             kVK_ANSI_RightBracket, kVK_ANSI_Backslash, kVK_ANSI_Semicolon,
             kVK_ANSI_Quote, kVK_ANSI_Comma, kVK_ANSI_Period, kVK_ANSI_Slash,
             kVK_Return, kVK_Delete, kVK_RightCommand, kVK_RightShift,
             kVK_RightOption, kVK_RightControl, kVK_LeftArrow, kVK_RightArrow,
             kVK_UpArrow, kVK_DownArrow, kVK_Help, kVK_Home, kVK_PageUp,
             kVK_ForwardDelete, kVK_End, kVK_PageDown, kVK_ContextualMenu,
             kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply,
             kVK_ANSI_KeypadPlus, kVK_ANSI_KeypadClear, kVK_ANSI_KeypadDivide,
             kVK_ANSI_KeypadEnter, kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEquals,
             kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2,
             kVK_ANSI_Keypad3, kVK_ANSI_Keypad4, kVK_ANSI_Keypad5,
             kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8,
             kVK_ANSI_Keypad9, kVK_JIS_Yen, kVK_JIS_Underscore,
             kVK_JIS_KeypadComma, kVK_JIS_Kana, kVK_F6, kVK_F7, kVK_F8,
             kVK_F9, kVK_F10,
             kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17,
             kVK_F18, kVK_F19, kVK_F20, kVK_VolumeUp, kVK_VolumeDown, kVK_Mute:
            return .right

        case kVK_Space, kVK_Function:
            return .neutral

        default:
            return .unknown
        }
    }
}
