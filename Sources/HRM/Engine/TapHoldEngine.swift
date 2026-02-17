import CoreGraphics
import Foundation

protocol TapHoldEngineDelegate: AnyObject {
    func engineDidResolveHold(binding: KeyBinding)
    func engineDidResolveHoldRelease(binding: KeyBinding)
    func engineDidResolveTap(binding: KeyBinding)
    func engineShouldFlushBufferedEvents(_ events: [BufferedEvent])
}

final class TapHoldEngine {
    private var machines: [UInt16: KeyStateMachine] = [:]
    private var buffer = EventBuffer()
    private var config: Configuration
    private var passedThroughKeys: Set<UInt16> = []

    weak var delegate: TapHoldEngineDelegate?

    init(config: Configuration) {
        self.config = config
        rebuildMachines()
    }

    func updateConfig(_ newConfig: Configuration) {
        self.config = newConfig
        rebuildMachines()
    }

    // MARK: - Event Processing

    enum EventResult {
        case passThrough
        case suppress
    }

    /// Modifier flags that indicate a physical modifier key is held.
    private static let physicalModifierMask: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand,
    ]

    /// Tracks which modifier flags were synthesized by HRM (via hold resolution).
    var syntheticModifierFlags: CGEventFlags = []

    func handleKeyDown(keyCode: UInt16, event: CGEvent, timestamp: TimeInterval) -> EventResult {
        // If this is a configured mod-tap key
        if let machine = machines[keyCode] {
            // Key was passed through on press (quick-tap or require-prior-idle),
            // pass through repeat/autorepeat events too
            if passedThroughKeys.contains(keyCode) {
                return .passThrough
            }

            // Ignore auto-repeat events for keys already in undecided or hold state
            if machine.isUndecided || machine.state == .hold {
                return .suppress
            }

            // If a real (non-HRM) modifier key is already held, pass through
            // immediately — don't enter the undecided state. This lets physical
            // Shift+A type "A", while still allowing HRM mod combos (e.g. D+A).
            let realFlags = event.flags.intersection(Self.physicalModifierMask).subtracting(syntheticModifierFlags)
            if !realFlags.isEmpty {
                passedThroughKeys.insert(keyCode)
                _ = machine.onPress(at: timestamp)
                for (code, m) in machines where code != keyCode {
                    m.recordOtherEvent(at: timestamp)
                }
                return .passThrough
            }

            // Notify other undecided machines about this key press before
            // starting our own state machine — this lets an already-held
            // mod-tap key (e.g. F/Shift) resolve as hold when another
            // mod-tap key (e.g. D) is pressed as a regular keystroke.
            let position = positionForKeyCode(keyCode)
            for (code, m) in machines where code != keyCode && m.isUndecided {
                let otherAction = m.onOtherKeyDown(keyCode: keyCode, position: position, at: timestamp)
                if otherAction != .none {
                    handleAction(otherAction, machine: m)
                }
            }

            let action = machine.onPress(at: timestamp)

            // Record event on all other machines (must happen regardless of
            // whether this key passes through or enters undecided, so that
            // require-prior-idle chains correctly across mod-tap keys)
            for (code, m) in machines where code != keyCode {
                m.recordOtherEvent(at: timestamp)
            }

            if action == .resolvedTap {
                if anyMachineUndecided {
                    // Another machine is undecided (possibly a modifier).
                    // Don't pass through — force into undecided so the
                    // modifier can resolve before this key emits its tap.
                    machine.forceUndecided(at: timestamp)
                    return .suppress
                } else {
                    // No undecided machines — safe to pass through
                    passedThroughKeys.insert(keyCode)
                    return .passThrough
                }
            }

            handleAction(action, machine: machine)
            return .suppress
        }

        // This is a non-mod-tap key

        // Record as other event on all machines
        for (_, m) in machines {
            m.recordOtherEvent(at: timestamp)
        }

        let position = positionForKeyCode(keyCode)

        // If any machine is undecided, buffer the event and notify machines
        var anyResolved = false
        for (_, m) in machines where m.isUndecided {
            let action = m.onOtherKeyDown(keyCode: keyCode, position: position, at: timestamp)
            if action != .none {
                handleAction(action, machine: m)
                anyResolved = true
            }
        }

        // If any machine is still undecided, buffer this event
        if anyMachineUndecided {
            buffer.append(BufferedEvent(
                event: event.copy()!,
                keyCode: keyCode,
                isKeyDown: true,
                timestamp: timestamp
            ))
            return .suppress
        }

        // If we resolved something, flush buffer then pass through
        if anyResolved {
            flushBuffer()
        }

        return .passThrough
    }

    func handleKeyUp(keyCode: UInt16, event: CGEvent, timestamp: TimeInterval) -> EventResult {
        if let machine = machines[keyCode] {
            // Key was passed through on press (require-prior-idle / quick-tap),
            // pass through release too without synthesizing
            if passedThroughKeys.remove(keyCode) != nil {
                _ = machine.onRelease(at: timestamp)
                return .passThrough
            }

            let action = machine.onRelease(at: timestamp)

            // Resolve other undecided machines BEFORE emitting this key's
            // action — e.g. F must activate shift before D emits its tap,
            // so that the tap produces 'D' not 'd'.
            // Only notify machines pressed BEFORE this one to distinguish
            // shift (F↓ D↓ D↑ F↑ → F=hold, D=tap) from
            // roll (A↓ S↓ A↑ S↑ → both taps).
            let position = positionForKeyCode(keyCode)
            for (code, m) in machines where code != keyCode && m.isUndecided {
                if m.pressTimestamp < machine.pressTimestamp {
                    let otherAction = m.onOtherKeyUp(keyCode: keyCode, position: position, at: timestamp)
                    if otherAction != .none {
                        handleAction(otherAction, machine: m)
                    }
                }
            }

            handleAction(action, machine: machine)

            if !anyMachineUndecided && !buffer.isEmpty {
                flushBuffer()
            }

            return .suppress
        }

        // Non-mod-tap key up
        let position = positionForKeyCode(keyCode)
        var anyResolved = false
        for (_, m) in machines where m.isUndecided {
            let action = m.onOtherKeyUp(keyCode: keyCode, position: position, at: timestamp)
            if action != .none {
                handleAction(action, machine: m)
                anyResolved = true
            }
        }

        if anyMachineUndecided {
            buffer.append(BufferedEvent(
                event: event.copy()!,
                keyCode: keyCode,
                isKeyDown: false,
                timestamp: timestamp
            ))
            return .suppress
        }

        if anyResolved {
            flushBuffer()
        }

        return .passThrough
    }

    // MARK: - Helpers

    private var anyMachineUndecided: Bool {
        machines.values.contains { $0.isUndecided }
    }

    private func handleAction(_ action: KeyMachineAction, machine: KeyStateMachine) {
        switch action {
        case .none:
            break
        case .resolvedHold:
            delegate?.engineDidResolveHold(binding: machine.binding)
            if !anyMachineUndecided {
                flushBuffer()
            }
        case .resolvedTap:
            delegate?.engineDidResolveTap(binding: machine.binding)
            if !anyMachineUndecided {
                flushBuffer()
            }
        case .holdRelease:
            delegate?.engineDidResolveHoldRelease(binding: machine.binding)
        }
    }

    private func flushBuffer() {
        let events = buffer.drainAll()
        if !events.isEmpty {
            delegate?.engineShouldFlushBufferedEvents(events)
        }
    }

    private func rebuildMachines() {
        machines.removeAll()
        for binding in config.keyBindings where binding.enabled && binding.modifier != nil {
            machines[binding.keyCode] = KeyStateMachine(binding: binding, config: config)
        }
    }

    private func positionForKeyCode(_ keyCode: UInt16) -> KeyPosition? {
        // Check all bindings (including disabled) for position info
        config.keyBindings.first { $0.keyCode == keyCode }?.position
    }
}
