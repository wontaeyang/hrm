import CoreGraphics
import Foundation

final class EventTapManager: TapHoldEngineDelegate {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var engine: TapHoldEngine
    private let synthesizer = EventSynthesizer()
    private var currentModifierFlags: CGEventFlags = []
    /// Key codes currently being suppressed by the engine (undecided/hold).
    /// Used by the callback to skip auto-repeat events without entering the engine.
    private(set) var suppressedKeyCodes: Set<UInt16> = []

    private(set) var isRunning = false

    init(engine: TapHoldEngine) {
        self.engine = engine
        engine.delegate = self
    }

    func start() {
        guard !isRunning else { return }

        tapThread = Thread { [weak self] in
            self?.runEventTapLoop()
        }
        tapThread?.name = "com.hrm.eventtap"
        tapThread?.qualityOfService = .userInteractive
        tapThread?.start()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let tap = eventTap {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func reenable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func updateEngine(_ engine: TapHoldEngine) {
        self.engine = engine
        engine.delegate = self
    }

    // MARK: - Event Processing (called from C callback)

    func processEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let timestamp = ProcessInfo.processInfo.systemUptime

        let result: TapHoldEngine.EventResult

        if type == .keyDown {
            result = engine.handleKeyDown(keyCode: keyCode, event: event, timestamp: timestamp)
        } else if type == .keyUp {
            result = engine.handleKeyUp(keyCode: keyCode, event: event, timestamp: timestamp)
        } else {
            // flagsChanged — pass through
            return Unmanaged.passUnretained(event)
        }

        switch result {
        case .passThrough:
            if type == .keyDown {
                suppressedKeyCodes.remove(keyCode)
            }
            if !currentModifierFlags.isEmpty {
                event.flags = event.flags.union(currentModifierFlags)
            }
            return Unmanaged.passUnretained(event)
        case .suppress:
            if type == .keyDown {
                suppressedKeyCodes.insert(keyCode)
            } else if type == .keyUp {
                suppressedKeyCodes.remove(keyCode)
            }
            return nil
        }
    }

    // MARK: - TapHoldEngineDelegate

    func engineDidResolveHold(binding: KeyBinding) {
        guard let modifier = binding.modifier else { return }
        currentModifierFlags.insert(modifier.flag)
        engine.syntheticModifierFlags = currentModifierFlags
        let flagKeyCode = binding.position.hand == .left
            ? modifier.leftFlagsChanged
            : modifier.rightFlagsChanged
        synthesizer.postFlagsChanged(keyCode: flagKeyCode, flags: currentModifierFlags)
    }

    func engineDidResolveHoldRelease(binding: KeyBinding) {
        guard let modifier = binding.modifier else { return }
        currentModifierFlags.remove(modifier.flag)
        engine.syntheticModifierFlags = currentModifierFlags
        let flagKeyCode = binding.position.hand == .left
            ? modifier.leftFlagsChanged
            : modifier.rightFlagsChanged
        synthesizer.postFlagsChanged(keyCode: flagKeyCode, flags: currentModifierFlags)
    }

    func engineDidResolveTap(binding: KeyBinding) {
        synthesizer.postKeyDown(keyCode: binding.keyCode, flags: currentModifierFlags)
        synthesizer.postKeyUp(keyCode: binding.keyCode, flags: currentModifierFlags)
    }

    func engineShouldFlushBufferedEvents(_ events: [BufferedEvent]) {
        for buffered in events {
            // Apply current modifier flags to buffered events
            if !currentModifierFlags.isEmpty {
                buffered.event.flags = buffered.event.flags.union(currentModifierFlags)
            }
            synthesizer.postEvent(buffered.event)
        }
    }

    // MARK: - Private

    private func runEventTapLoop() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("HRM: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else { return }

        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        CFRunLoopRun()
    }
}
