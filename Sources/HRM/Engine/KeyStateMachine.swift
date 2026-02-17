import Foundation

enum KeyState: Equatable {
    case idle
    case undecided
    case hold
    case tap
    case quickTapWindow
}

enum KeyMachineAction: Equatable {
    case none
    case resolvedHold
    case resolvedTap
    case holdRelease
}

final class KeyStateMachine {
    let binding: KeyBinding
    private(set) var state: KeyState = .idle
    private(set) var pressTimestamp: TimeInterval = 0
    private(set) var lastTapTimestamp: TimeInterval = 0
    private(set) var lastEventTimestamp: TimeInterval = 0

    private let quickTapTerm: TimeInterval
    private let requirePriorIdle: TimeInterval
    private let holdTriggerPositions: Set<KeyPosition>?
    private let holdTriggerOnRelease: Bool

    init(binding: KeyBinding, config: Configuration) {
        self.binding = binding
        self.quickTapTerm = Double(config.effectiveQuickTapTerm(for: binding)) / 1000.0
        self.requirePriorIdle = Double(config.effectiveRequirePriorIdle(for: binding)) / 1000.0
        self.holdTriggerOnRelease = config.holdTriggerOnRelease
        if config.effectiveBilateralFiltering(for: binding) {
            self.holdTriggerPositions = Set(KeyPosition.allCases.filter { $0.hand != binding.position.hand })
        } else {
            self.holdTriggerPositions = nil
        }
    }

    // For testing: create with explicit parameters
    init(
        binding: KeyBinding,
        quickTapTerm: TimeInterval = 0,
        requirePriorIdle: TimeInterval = 0,
        holdTriggerPositions: Set<KeyPosition>? = nil,
        holdTriggerOnRelease: Bool = false
    ) {
        self.binding = binding
        self.quickTapTerm = quickTapTerm
        self.requirePriorIdle = requirePriorIdle
        self.holdTriggerPositions = holdTriggerPositions
        self.holdTriggerOnRelease = holdTriggerOnRelease
    }

    var isUndecided: Bool { state == .undecided }

    func forceUndecided(at timestamp: TimeInterval) {
        state = .undecided
        pressTimestamp = timestamp
    }

    // MARK: - Events

    func onPress(at timestamp: TimeInterval) -> KeyMachineAction {
        // Ignore repeat keyDown events while already holding or undecided
        if state == .hold || state == .undecided {
            return .none
        }

        // Quick-tap: if within quick-tap window, immediately resolve as tap
        if state == .quickTapWindow && quickTapTerm > 0 {
            let sinceLastTap = timestamp - lastTapTimestamp
            if sinceLastTap <= quickTapTerm {
                state = .tap
                pressTimestamp = timestamp
                return .resolvedTap
            }
        }

        // Require prior idle: if last event was too recent, immediately resolve as tap
        if requirePriorIdle > 0 && lastEventTimestamp > 0 {
            let idleTime = timestamp - lastEventTimestamp
            if idleTime < requirePriorIdle {
                state = .tap
                pressTimestamp = timestamp
                return .resolvedTap
            }
        }

        state = .undecided
        pressTimestamp = timestamp
        return .none
    }

    func onRelease(at timestamp: TimeInterval) -> KeyMachineAction {
        switch state {
        case .undecided:
            // Timeless: self-release always produces tap
            resolveAsTap(at: timestamp)
            return .resolvedTap
        case .hold:
            state = .idle
            return .holdRelease
        case .tap:
            resolveAsTap(at: timestamp)
            return .resolvedTap
        default:
            state = .idle
            return .none
        }
    }

    func onOtherKeyDown(keyCode: UInt16, position: KeyPosition?, at timestamp: TimeInterval) -> KeyMachineAction {
        guard state == .undecided else { return .none }

        // Bilateral filtering on key down (skip if holdTriggerOnRelease is enabled)
        if !holdTriggerOnRelease, let positions = holdTriggerPositions, let pos = position {
            if !positions.contains(pos) {
                resolveAsTap(at: timestamp)
                return .resolvedTap
            }
        }

        // Timeless: other key down stays undecided (waits for release)
        return .none
    }

    func onOtherKeyUp(keyCode: UInt16, position: KeyPosition?, at timestamp: TimeInterval) -> KeyMachineAction {
        guard state == .undecided else { return .none }

        // Bilateral filtering on key up (only when holdTriggerOnRelease is enabled)
        if holdTriggerOnRelease, let positions = holdTriggerPositions, let pos = position {
            if !positions.contains(pos) {
                // Same hand: don't resolve as hold, stay undecided
                return .none
            }
        }

        // Timeless: other key pressed and released = hold
        state = .hold
        return .resolvedHold
    }

    func recordOtherEvent(at timestamp: TimeInterval) {
        lastEventTimestamp = timestamp
    }

    // MARK: - Private

    private func resolveAsTap(at timestamp: TimeInterval) {
        lastTapTimestamp = timestamp
        if quickTapTerm > 0 {
            state = .quickTapWindow
        } else {
            state = .idle
        }
    }
}
