import Carbon.HIToolbox

enum KeyCode {
    // Home row
    static let a: UInt16 = UInt16(kVK_ANSI_A)         // 0x00
    static let s: UInt16 = UInt16(kVK_ANSI_S)         // 0x01
    static let d: UInt16 = UInt16(kVK_ANSI_D)         // 0x02
    static let f: UInt16 = UInt16(kVK_ANSI_F)         // 0x03
    static let h: UInt16 = UInt16(kVK_ANSI_H)         // 0x04
    static let g: UInt16 = UInt16(kVK_ANSI_G)         // 0x05
    static let j: UInt16 = UInt16(kVK_ANSI_J)         // 0x26
    static let k: UInt16 = UInt16(kVK_ANSI_K)         // 0x28
    static let l: UInt16 = UInt16(kVK_ANSI_L)         // 0x25
    static let semicolon: UInt16 = UInt16(kVK_ANSI_Semicolon) // 0x29

    // Space
    static let space: UInt16 = UInt16(kVK_Space)       // 0x31

    // Arrow keys
    static let leftArrow: UInt16 = UInt16(kVK_LeftArrow)   // 0x7B
    static let downArrow: UInt16 = UInt16(kVK_DownArrow)   // 0x7D
    static let upArrow: UInt16 = UInt16(kVK_UpArrow)       // 0x7E
    static let rightArrow: UInt16 = UInt16(kVK_RightArrow) // 0x7C
}
