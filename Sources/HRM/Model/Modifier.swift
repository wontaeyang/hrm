import CoreGraphics
import SwiftUI

enum Modifier: String, Codable, CaseIterable, Identifiable {
    case shift
    case control
    case option
    case command

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shift: "Shift"
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        }
    }

    var symbol: String {
        switch self {
        case .shift: "⇧"
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .control: .maskControl
        case .option: .maskAlternate
        case .command: .maskCommand
        }
    }

    var leftFlagsChanged: UInt16 {
        switch self {
        case .shift: 0x38    // kVK_Shift
        case .control: 0x3B  // kVK_Control
        case .option: 0x3A   // kVK_Option
        case .command: 0x37  // kVK_Command
        }
    }

    var rightFlagsChanged: UInt16 {
        switch self {
        case .shift: 0x3C    // kVK_RightShift
        case .control: 0x3E  // kVK_RightControl
        case .option: 0x3D   // kVK_RightOption
        case .command: 0x36  // kVK_RightCommand
        }
    }

    var themeColor: Color {
        switch self {
        case .shift:   .orange
        case .control: .teal
        case .option:  .purple
        case .command: .blue
        }
    }
}
