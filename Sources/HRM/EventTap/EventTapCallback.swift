import CoreGraphics
import Foundation

// Global C callback for CGEventTap — must be a free function
func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    // Handle tap disabled by timeout — re-enable it
    if type == .tapDisabledByTimeout {
        manager.reenable()
        return Unmanaged.passUnretained(event)
    }

    // Only handle key events and flags changed
    guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
        return Unmanaged.passUnretained(event)
    }

    // Skip synthetic events to prevent feedback loops
    if EventSynthesizer.isSynthetic(event) {
        return Unmanaged.passUnretained(event)
    }

    return manager.processEvent(proxy: proxy, type: type, event: event)
}
