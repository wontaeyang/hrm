import CoreGraphics
import Foundation

struct BufferedEvent {
    let event: CGEvent
    let keyCode: UInt16
    let isKeyDown: Bool
    let timestamp: TimeInterval
}

struct EventBuffer {
    private var events: [BufferedEvent] = []

    var isEmpty: Bool { events.isEmpty }

    mutating func append(_ event: BufferedEvent) {
        events.append(event)
    }

    mutating func drainAll() -> [BufferedEvent] {
        let drained = events
        events.removeAll()
        return drained
    }
}
