import Testing
import CoreGraphics
@testable import HRM

// Test delegate that records all engine actions
final class TestEngineDelegate: TapHoldEngineDelegate {
    enum Action: Equatable {
        case hold(String)
        case holdRelease(String)
        case tap(String)
    }

    var holds: [KeyBinding] = []
    var holdReleases: [KeyBinding] = []
    var taps: [KeyBinding] = []
    var flushedEvents: [[BufferedEvent]] = []
    var actionLog: [Action] = []

    func engineDidResolveHold(binding: KeyBinding) {
        holds.append(binding)
        actionLog.append(.hold(binding.label))
    }
    func engineDidResolveHoldRelease(binding: KeyBinding) {
        holdReleases.append(binding)
        actionLog.append(.holdRelease(binding.label))
    }
    func engineDidResolveTap(binding: KeyBinding) {
        taps.append(binding)
        actionLog.append(.tap(binding.label))
    }
    func engineShouldFlushBufferedEvents(_ events: [BufferedEvent]) { flushedEvents.append(events) }

    func reset() {
        holds.removeAll()
        holdReleases.removeAll()
        taps.removeAll()
        flushedEvents.removeAll()
        actionLog.removeAll()
    }
}

@Suite("TapHoldEngine Tests")
struct TapHoldEngineTests {
    // Key codes
    let keyA: UInt16 = 0x00
    let keyS: UInt16 = 0x01
    let keyE: UInt16 = 0x0E  // non-mod-tap key
    let keyJ: UInt16 = 0x26

    func makeConfig() -> Configuration {
        var config = DefaultConfiguration.make()
        config.requirePriorIdleMs = 0
        config.bilateralFiltering = false
        return config
    }

    func makeEngine(config: Configuration? = nil) -> (TapHoldEngine, TestEngineDelegate) {
        let cfg = config ?? makeConfig()
        let engine = TapHoldEngine(config: cfg)
        let delegate = TestEngineDelegate()
        engine.delegate = delegate
        return (engine, delegate)
    }

    func makeCGEvent(keyCode: UInt16, keyDown: Bool) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown)!
        return event
    }

    // MARK: - Basic Tap

    @Test("Tap: quick press and release of mod-tap key produces tap")
    func basicTap() {
        let (engine, delegate) = makeEngine()
        let downEvent = makeCGEvent(keyCode: keyA, keyDown: true)
        let result1 = engine.handleKeyDown(keyCode: keyA, event: downEvent, timestamp: 1.0)
        #expect(result1 == .suppress)

        let upEvent = makeCGEvent(keyCode: keyA, keyDown: false)
        let result2 = engine.handleKeyUp(keyCode: keyA, event: upEvent, timestamp: 1.100)
        #expect(result2 == .suppress)  // synthetic tap already emitted
        #expect(delegate.taps.count == 1)
        #expect(delegate.taps[0].label == "A")
    }

    // MARK: - Non-mod-tap key passthrough

    @Test("Non-mod-tap key passes through when no undecided machines")
    func nonModTapPassthrough() {
        let (engine, _) = makeEngine()
        let event = makeCGEvent(keyCode: keyE, keyDown: true)
        let result = engine.handleKeyDown(keyCode: keyE, event: event, timestamp: 1.0)
        #expect(result == .passThrough)
    }

    // MARK: - Buffering

    @Test("Other key is buffered while mod-tap key is undecided")
    func bufferingWhileUndecided() {
        let (engine, delegate) = makeEngine()

        // Press A (mod-tap)
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.0)
        #expect(r1 == .suppress)

        // Press E (regular key) while A undecided — should be buffered
        let eDown = makeCGEvent(keyCode: keyE, keyDown: true)
        let r2 = engine.handleKeyDown(keyCode: keyE, event: eDown, timestamp: 1.050)
        #expect(r2 == .suppress)

        // Release E — timeless policy sees otherKeyUp → hold
        let eUp = makeCGEvent(keyCode: keyE, keyDown: false)
        let r3 = engine.handleKeyUp(keyCode: keyE, event: eUp, timestamp: 1.080)
        // After hold resolves, buffer should flush
        #expect(r3 == .passThrough)  // eUp itself passes through since no undecided
        #expect(delegate.holds.count == 1)
        #expect(delegate.flushedEvents.count == 1)
    }

    // MARK: - Key Rollover

    @Test("Fast key roll A↓ S↓ A↑ S↑ produces two taps")
    func keyRollover() {
        let (engine, delegate) = makeEngine()

        // A↓
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.000)

        // S↓ (both A and S are mod-tap keys)
        let sDown = makeCGEvent(keyCode: keyS, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyS, event: sDown, timestamp: 1.030)

        // A↑ — A was undecided, released quickly → tap
        let aUp = makeCGEvent(keyCode: keyA, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyA, event: aUp, timestamp: 1.060)
        #expect(delegate.taps.count >= 1)
        #expect(delegate.taps[0].label == "A")

        // S↑ — S was undecided, released quickly → tap
        let sUp = makeCGEvent(keyCode: keyS, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyS, event: sUp, timestamp: 1.090)
        #expect(delegate.taps.count >= 2)
        #expect(delegate.taps[1].label == "S")
    }

    // MARK: - Require prior idle passthrough (no double character)

    @Test("Require prior idle: pass through produces single tap, no synthetic duplicate")
    func requirePriorIdleNoDuplicate() {
        var config = makeConfig()
        config.requirePriorIdleMs = 150
        let (engine, delegate) = makeEngine(config: config)

        // Simulate recent typing activity
        let eDown = makeCGEvent(keyCode: keyE, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyE, event: eDown, timestamp: 0.900)
        let eUp = makeCGEvent(keyCode: keyE, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyE, event: eUp, timestamp: 0.950)

        // Press S (mod-tap) shortly after — requirePriorIdle triggers
        let sDown = makeCGEvent(keyCode: keyS, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyS, event: sDown, timestamp: 1.0)
        #expect(r1 == .passThrough)  // original passes through
        #expect(delegate.taps.isEmpty)  // no synthetic tap

        // Release S — should also pass through, no synthesis
        let sUp = makeCGEvent(keyCode: keyS, keyDown: false)
        let r2 = engine.handleKeyUp(keyCode: keyS, event: sUp, timestamp: 1.050)
        #expect(r2 == .passThrough)
        #expect(delegate.taps.isEmpty)  // still no synthetic tap
    }

    // MARK: - Hold modifier applied to subsequent keys

    @Test("Held mod-tap key: subsequent regular keys pass through after hold resolves")
    func holdThenRepeatRegularKey() {
        let (engine, delegate) = makeEngine()

        // A↓ (mod-tap, Shift)
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.0)

        // E↓ while A undecided — buffered
        let eDown1 = makeCGEvent(keyCode: keyE, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyE, event: eDown1, timestamp: 1.050)
        #expect(r1 == .suppress)

        // E↑ — timeless resolves A as hold, buffer flushed
        let eUp1 = makeCGEvent(keyCode: keyE, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyE, event: eUp1, timestamp: 1.080)
        #expect(delegate.holds.count == 1)

        // E↓ again — A is now in hold, no undecided machines, should pass through
        let eDown2 = makeCGEvent(keyCode: keyE, keyDown: true)
        let r2 = engine.handleKeyDown(keyCode: keyE, event: eDown2, timestamp: 1.120)
        #expect(r2 == .passThrough)

        // E↑ — should also pass through
        let eUp2 = makeCGEvent(keyCode: keyE, keyDown: false)
        let r3 = engine.handleKeyUp(keyCode: keyE, event: eUp2, timestamp: 1.150)
        #expect(r3 == .passThrough)
    }

    // MARK: - Key repeat of mod-tap key in hold state

    @Test("Key repeat of held mod-tap key is suppressed")
    func keyRepeatInHoldState() {
        let (engine, delegate) = makeEngine()

        // A↓
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.0)

        // E↓ + E↑ → resolves A as hold
        let eDown = makeCGEvent(keyCode: keyE, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyE, event: eDown, timestamp: 1.050)
        let eUp = makeCGEvent(keyCode: keyE, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyE, event: eUp, timestamp: 1.080)
        #expect(delegate.holds.count == 1)

        // OS repeat keyDown for A — should suppress, not reset state
        let aRepeat = makeCGEvent(keyCode: keyA, keyDown: true)
        let r = engine.handleKeyDown(keyCode: keyA, event: aRepeat, timestamp: 1.250)
        #expect(r == .suppress)

        // Should still be exactly one hold, no extra resolves
        #expect(delegate.holds.count == 1)
        #expect(delegate.taps.isEmpty)
    }

    // MARK: - Quick tap key repeat

    @Test("Quick tap: autorepeat keyDown events pass through after quick-tap resolves")
    func quickTapRepeat() {
        var config = makeConfig()
        config.quickTapTermMs = 200
        let (engine, delegate) = makeEngine(config: config)

        // First tap: A↓ → suppress (undecided)
        let aDown1 = makeCGEvent(keyCode: keyA, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyA, event: aDown1, timestamp: 1.0)
        #expect(r1 == .suppress)

        // First release: A↑ → resolvedTap, enters quickTapWindow
        let aUp1 = makeCGEvent(keyCode: keyA, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyA, event: aUp1, timestamp: 1.080)
        #expect(delegate.taps.count == 1)

        // Quick tap second press within window: should pass through
        let aDown2 = makeCGEvent(keyCode: keyA, keyDown: true)
        let r2 = engine.handleKeyDown(keyCode: keyA, event: aDown2, timestamp: 1.150)
        #expect(r2 == .passThrough)

        // Autorepeat keyDown: should also pass through
        let aRepeat1 = makeCGEvent(keyCode: keyA, keyDown: true)
        let r3 = engine.handleKeyDown(keyCode: keyA, event: aRepeat1, timestamp: 1.200)
        #expect(r3 == .passThrough)

        // Another autorepeat: should also pass through
        let aRepeat2 = makeCGEvent(keyCode: keyA, keyDown: true)
        let r4 = engine.handleKeyDown(keyCode: keyA, event: aRepeat2, timestamp: 1.250)
        #expect(r4 == .passThrough)

        // Release: should pass through
        let aUp2 = makeCGEvent(keyCode: keyA, keyDown: false)
        let r5 = engine.handleKeyUp(keyCode: keyA, event: aUp2, timestamp: 1.300)
        #expect(r5 == .passThrough)
    }

    // MARK: - Mod-tap key pressed under another mod-tap hold

    @Test("Shift mod-tap held while another mod-tap key is tapped: hold + tap")
    func modTapUnderModTapHold() {
        let (engine, delegate) = makeEngine()
        let keyF: UInt16 = 0x03  // F = shift mod-tap
        let keyD: UInt16 = 0x02  // D = command mod-tap

        // F↓ — enters undecided
        let fDown = makeCGEvent(keyCode: keyF, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyF, event: fDown, timestamp: 1.0)
        #expect(r1 == .suppress)

        // D↓ — F should be notified (otherKeyDown), D enters undecided
        let dDown = makeCGEvent(keyCode: keyD, keyDown: true)
        let r2 = engine.handleKeyDown(keyCode: keyD, event: dDown, timestamp: 1.050)
        #expect(r2 == .suppress)

        // D↑ — F should resolve as hold BEFORE D emits tap,
        // so that shift is active when 'd' is synthesized → 'D'
        let dUp = makeCGEvent(keyCode: keyD, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyD, event: dUp, timestamp: 1.080)

        #expect(delegate.holds.count == 1)
        #expect(delegate.holds[0].label == "F")
        #expect(delegate.taps.count == 1)
        #expect(delegate.taps[0].label == "D")
        // Verify ordering: hold(F) must come before tap(D)
        #expect(delegate.actionLog == [.hold("F"), .tap("D")])

        // F↑ — hold release
        let fUp = makeCGEvent(keyCode: keyF, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyF, event: fUp, timestamp: 1.200)
        #expect(delegate.holdReleases.count == 1)
        #expect(delegate.holdReleases[0].label == "F")
    }

    // MARK: - Require prior idle does not bypass undecided modifier

    @Test("Require prior idle: mod-tap key suppressed when another mod-tap is undecided")
    func requirePriorIdleRespectsUndecidedModifier() {
        var config = makeConfig()
        config.requirePriorIdleMs = 150
        let (engine, delegate) = makeEngine(config: config)
        let keyJ: UInt16 = 0x26  // J = shift mod-tap

        // Simulate recent activity so requirePriorIdle would normally trigger
        let eDown = makeCGEvent(keyCode: keyE, keyDown: true)
        _ = engine.handleKeyDown(keyCode: keyE, event: eDown, timestamp: 0.900)
        let eUp = makeCGEvent(keyCode: keyE, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyE, event: eUp, timestamp: 0.950)

        // J↓ — enters undecided (enough idle since E)
        let jDown = makeCGEvent(keyCode: keyJ, keyDown: true)
        let r1 = engine.handleKeyDown(keyCode: keyJ, event: jDown, timestamp: 1.200)
        #expect(r1 == .suppress)

        // A↓ — requirePriorIdle would trigger (J↓ was recent),
        // but J is undecided so A must NOT pass through
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        let r2 = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.250)
        #expect(r2 == .suppress)  // must suppress, not passthrough
        #expect(delegate.taps.isEmpty)  // no premature tap

        // A↑ — J resolves as hold (shift), then A emits tap
        let aUp = makeCGEvent(keyCode: keyA, keyDown: false)
        _ = engine.handleKeyUp(keyCode: keyA, event: aUp, timestamp: 1.280)

        #expect(delegate.holds.count == 1)
        #expect(delegate.holds[0].label == "J")
        #expect(delegate.taps.count == 1)
        #expect(delegate.taps[0].label == "A")
        // Verify ordering: hold(J) before tap(A)
        #expect(delegate.actionLog == [.hold("J"), .tap("A")])
    }

    // MARK: - Config update

    @Test("Config update rebuilds machines")
    func configUpdate() {
        let (engine, delegate) = makeEngine()

        // Disable all bindings
        var newConfig = makeConfig()
        for i in newConfig.keyBindings.indices {
            newConfig.keyBindings[i].enabled = false
        }
        engine.updateConfig(newConfig)

        // Now A should pass through since it's disabled
        let aDown = makeCGEvent(keyCode: keyA, keyDown: true)
        let result = engine.handleKeyDown(keyCode: keyA, event: aDown, timestamp: 1.0)
        #expect(result == .passThrough)
        #expect(delegate.holds.isEmpty)
        #expect(delegate.taps.isEmpty)
    }
}
