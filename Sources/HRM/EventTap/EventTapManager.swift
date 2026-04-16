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

    /// Whether Caps Lock → Backspace remap is active.
    private var _remapCapsLockToBackspace: Bool = false
    /// Tracks whether Caps Lock (remapped to F18) is physically held for auto-repeat.
    private var capsLockDown = false
    private var capsLockRepeatTimer: DispatchSourceTimer?

    // Caps Lock is remapped to F18 via hidutil at the HID level.
    // F18 CGEvent keycode = 79 (0x4F).
    private static let f18KeyCode: UInt16 = 0x4F
    private static let backspaceKeyCode: UInt16 = 0x33

    init(engine: TapHoldEngine) {
        self.engine = engine
        engine.delegate = self
    }

    func start() {
        guard !isRunning else { return }

        if _remapCapsLockToBackspace {
            Self.applyCapsLockHidutilMapping()
        }

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
        stopCapsLockRepeat()
        if _remapCapsLockToBackspace {
            Self.removeCapsLockHidutilMapping()
        }

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

    func setRemapCapsLockToBackspace(_ enabled: Bool) {
        let wasEnabled = _remapCapsLockToBackspace
        _remapCapsLockToBackspace = enabled
        if enabled && !wasEnabled {
            Self.applyCapsLockHidutilMapping()
        } else if !enabled && wasEnabled {
            stopCapsLockRepeat()
            capsLockDown = false
            Self.removeCapsLockHidutilMapping()
        }
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
            // F18 (remapped Caps Lock) → Backspace
            if keyCode == Self.f18KeyCode && _remapCapsLockToBackspace {
                if !capsLockDown {
                    capsLockDown = true
                    synthesizer.postKeyDown(keyCode: Self.backspaceKeyCode, flags: currentModifierFlags)
                    startCapsLockRepeat()
                }
                return nil
            }
            result = engine.handleKeyDown(keyCode: keyCode, event: event, timestamp: timestamp)
        } else if type == .keyUp {
            // F18 (remapped Caps Lock) → Backspace release
            if keyCode == Self.f18KeyCode && _remapCapsLockToBackspace {
                capsLockDown = false
                stopCapsLockRepeat()
                synthesizer.postKeyUp(keyCode: Self.backspaceKeyCode, flags: currentModifierFlags)
                return nil
            }
            result = engine.handleKeyUp(keyCode: keyCode, event: event, timestamp: timestamp)
        } else {
            // flagsChanged — pass through
            return Unmanaged.passUnretained(event)
        }

        switch result {
        case .passThrough:
            suppressedKeyCodes.remove(keyCode)
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

    // MARK: - Caps Lock Repeat

    private func startCapsLockRepeat() {
        stopCapsLockRepeat()
        let initialTicks = UserDefaults.standard.integer(forKey: "InitialKeyRepeat")
        let repeatTicks = UserDefaults.standard.integer(forKey: "KeyRepeat")
        let initialDelay = Double(initialTicks > 0 ? initialTicks : 25) * 0.015
        let repeatInterval = Double(repeatTicks > 0 ? repeatTicks : 6) * 0.015

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now() + initialDelay, repeating: repeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.capsLockDown else { return }
            self.synthesizer.postKeyDown(keyCode: Self.backspaceKeyCode, flags: self.currentModifierFlags)
        }
        timer.resume()
        capsLockRepeatTimer = timer
    }

    private func stopCapsLockRepeat() {
        capsLockRepeatTimer?.cancel()
        capsLockRepeatTimer = nil
    }

    // MARK: - hidutil Caps Lock Mapping

    /// Remap Caps Lock → F18 at the HID level using hidutil.
    private static func applyCapsLockHidutilMapping() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = [
            "property", "--set",
            """
            {"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006D}]}
            """,
        ]
        try? process.run()
        process.waitUntilExit()
    }

    /// Remove the Caps Lock → F18 mapping, restoring default behavior.
    private static func removeCapsLockHidutilMapping() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = [
            "property", "--set",
            """
            {"UserKeyMapping":[]}
            """,
        ]
        try? process.run()
        process.waitUntilExit()
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
