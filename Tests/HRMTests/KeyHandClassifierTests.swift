import Carbon.HIToolbox
import Testing
@testable import HRM

@Suite("KeyHandClassifier Tests")
struct KeyHandClassifierTests {
    @Test("Classifies standard keyboard sides")
    func classifiesStandardKeyboardSides() {
        let leftKeys = [
            kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G,
            kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B,
            kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T,
            kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
            kVK_ANSI_Grave, kVK_Escape, kVK_Tab, kVK_CapsLock, kVK_Command,
            kVK_Shift, kVK_Option, kVK_Control, kVK_ISO_Section, kVK_JIS_Eisu,
        ]
        let rightKeys = [
            kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
            kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
            kVK_ANSI_N, kVK_ANSI_M,
            kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0,
            kVK_ANSI_Minus, kVK_ANSI_Equal, kVK_ANSI_LeftBracket,
            kVK_ANSI_RightBracket, kVK_ANSI_Backslash, kVK_ANSI_Semicolon,
            kVK_ANSI_Quote, kVK_ANSI_Comma, kVK_ANSI_Period, kVK_ANSI_Slash,
            kVK_Return, kVK_Delete, kVK_RightCommand, kVK_RightShift,
            kVK_RightOption, kVK_RightControl, kVK_JIS_Yen, kVK_JIS_Underscore,
            kVK_JIS_KeypadComma, kVK_JIS_Kana,
        ]

        for keyCode in leftKeys {
            #expect(KeyHandClassifier.hand(for: UInt16(keyCode)) == .left)
        }
        for keyCode in rightKeys {
            #expect(KeyHandClassifier.hand(for: UInt16(keyCode)) == .right)
        }
    }

    @Test("Classifies right-side shortcut keys")
    func classifiesRightSideShortcutKeys() {
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_LeftArrow)) == .right)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_Home)) == .right)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_ANSI_Keypad0)) == .right)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_Return)) == .right)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_Delete)) == .right)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_F5)) == .left)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_F6)) == .right)
    }

    @Test("Classifies neutral and unknown keys")
    func classifiesNeutralAndUnknownKeys() {
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_Space)) == .neutral)
        #expect(KeyHandClassifier.hand(for: UInt16(kVK_Function)) == .neutral)
        #expect(KeyHandClassifier.hand(for: 0xFF) == .unknown)
    }

    @Test("Default bindings agree with their configured hand")
    func defaultBindingsAgreeWithConfiguredHand() {
        for binding in DefaultConfiguration.defaultKeyBindings {
            let expected: KeyHand = binding.position.hand == .left ? .left : .right
            #expect(KeyHandClassifier.hand(for: binding.keyCode) == expected)
        }
    }
}
