import CoreGraphics

final class EventSynthesizer {
    static let syntheticMarkerField = UInt32(42)
    private static let syntheticMarkerValue = Int64(0xDEAD_BEEF)

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.init(rawValue: syntheticMarkerField)!) == syntheticMarkerValue
    }

    static func markSynthetic(_ event: CGEvent) {
        event.setIntegerValueField(.init(rawValue: syntheticMarkerField)!, value: syntheticMarkerValue)
    }

    private let eventSource: CGEventSource?

    init() {
        self.eventSource = CGEventSource(stateID: .hidSystemState)
    }

    func postKeyDown(keyCode: UInt16, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else { return }
        event.flags = flags
        Self.markSynthetic(event)
        event.post(tap: .cghidEventTap)
    }

    func postKeyUp(keyCode: UInt16, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else { return }
        event.flags = flags
        Self.markSynthetic(event)
        event.post(tap: .cghidEventTap)
    }

    func postFlagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = flags
        Self.markSynthetic(event)
        event.post(tap: .cghidEventTap)
    }

    func postEvent(_ event: CGEvent) {
        Self.markSynthetic(event)
        event.post(tap: .cghidEventTap)
    }
}
