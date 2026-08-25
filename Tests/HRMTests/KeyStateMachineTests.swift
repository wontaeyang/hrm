import Foundation
import Testing
@testable import HRM

@Suite("KeyStateMachine Tests")
struct KeyStateMachineTests {
    static let testBinding = KeyBinding(
        keyCode: 0x00, modifier: .shift, enabled: true, position: .leftPinky
    )

    func makeMachine(
        quickTapTerm: TimeInterval = 0,
        requirePriorIdle: TimeInterval = 0,
        bilateralFiltering: Bool = false,
        holdTriggerOnRelease: Bool = false
    ) -> KeyStateMachine {
        KeyStateMachine(
            binding: Self.testBinding,
            quickTapTerm: quickTapTerm,
            requirePriorIdle: requirePriorIdle,
            bilateralFiltering: bilateralFiltering,
            holdTriggerOnRelease: holdTriggerOnRelease
        )
    }

    // MARK: - Basic State Transitions

    @Test("Initial state is idle")
    func initialState() {
        let sm = makeMachine()
        #expect(sm.state == .idle)
    }

    @Test("Press moves to undecided")
    func pressToUndecided() {
        let sm = makeMachine()
        let action = sm.onPress(at: 1.0)
        #expect(sm.state == .undecided)
        #expect(action == .none)
    }

    @Test("Self-release resolves as tap")
    func selfReleaseTap() {
        let sm = makeMachine()
        _ = sm.onPress(at: 1.0)
        let action = sm.onRelease(at: 1.300)
        #expect(action == .resolvedTap)
        #expect(sm.state == .idle)
    }

    @Test("Other key down+up resolves hold")
    func otherKeyDownUpHold() {
        let sm = makeMachine()
        _ = sm.onPress(at: 1.0)
        let a1 = sm.onOtherKeyDown(hand: .right, at: 1.050)
        #expect(a1 == .none)
        #expect(sm.state == .undecided)

        let a2 = sm.onOtherKeyUp(hand: .right, at: 1.080)
        #expect(a2 == .resolvedHold)
        #expect(sm.state == .hold)
    }

    // MARK: - Hold Release

    @Test("Hold state: release emits holdRelease")
    func holdReleaseAction() {
        let sm = makeMachine()
        _ = sm.onPress(at: 1.0)
        _ = sm.onOtherKeyDown(hand: .right, at: 1.050)
        _ = sm.onOtherKeyUp(hand: .right, at: 1.080)
        #expect(sm.state == .hold)

        let action = sm.onRelease(at: 1.300)
        #expect(action == .holdRelease)
        #expect(sm.state == .idle)
    }

    // MARK: - Key Repeat in Hold State

    @Test("Repeat press while in hold state is ignored")
    func repeatPressInHoldState() {
        let sm = makeMachine()
        _ = sm.onPress(at: 1.0)
        _ = sm.onOtherKeyDown(hand: .right, at: 1.050)
        _ = sm.onOtherKeyUp(hand: .right, at: 1.080)
        #expect(sm.state == .hold)

        // OS sends repeat keyDown — should be ignored, stay in hold
        let action = sm.onPress(at: 1.250)
        #expect(action == .none)
        #expect(sm.state == .hold)
    }

    // MARK: - Quick Tap

    @Test("Quick tap: double tap within window resolves immediately as tap")
    func quickTapWindow() {
        let sm = makeMachine(quickTapTerm: 0.150)
        _ = sm.onPress(at: 1.0)
        _ = sm.onRelease(at: 1.050)
        #expect(sm.state == .quickTapWindow)

        let action = sm.onPress(at: 1.100)
        #expect(action == .resolvedTap)
    }

    @Test("Quick tap: press outside window enters undecided normally")
    func quickTapExpired() {
        let sm = makeMachine(quickTapTerm: 0.150)
        _ = sm.onPress(at: 1.0)
        _ = sm.onRelease(at: 1.050)
        #expect(sm.state == .quickTapWindow)

        // 1.300 is 250ms after last tap (1.050), exceeds 150ms window
        let action = sm.onPress(at: 1.300)
        #expect(action == .none)
        #expect(sm.state == .undecided)
    }

    // MARK: - Require Prior Idle

    @Test("Require prior idle: recent activity resolves immediately as tap")
    func requirePriorIdleRecentActivity() {
        let sm = makeMachine(requirePriorIdle: 0.150)
        sm.recordOtherEvent(at: 0.950)
        let action = sm.onPress(at: 1.0)
        #expect(action == .resolvedTap)
    }

    @Test("Require prior idle: sufficient idle enters undecided normally")
    func requirePriorIdleSufficientIdle() {
        let sm = makeMachine(requirePriorIdle: 0.150)
        sm.recordOtherEvent(at: 0.800)
        let action = sm.onPress(at: 1.0)
        #expect(action == .none)
        #expect(sm.state == .undecided)
    }

    // MARK: - Bilateral Filtering

    @Test("Bilateral: other key from wrong hand resolves as tap")
    func bilateralWrongHand() {
        let sm = makeMachine(bilateralFiltering: true)
        _ = sm.onPress(at: 1.0)

        let action = sm.onOtherKeyDown(hand: .left, at: 1.050)
        #expect(action == .resolvedTap)
    }

    @Test("Bilateral: other key from correct hand proceeds normally")
    func bilateralCorrectHand() {
        let sm = makeMachine(bilateralFiltering: true)
        _ = sm.onPress(at: 1.0)

        let action = sm.onOtherKeyDown(hand: .right, at: 1.050)
        #expect(action == .none)
        #expect(sm.state == .undecided)
    }

    @Test("Bilateral: neutral and unknown keys resolve as taps on key down")
    func bilateralNeutralAndUnknownKeysResolveAsTapOnKeyDown() {
        for hand in [KeyHand.neutral, .unknown] {
            let sm = makeMachine(bilateralFiltering: true)
            _ = sm.onPress(at: 1.0)

            let action = sm.onOtherKeyDown(hand: hand, at: 1.050)
            #expect(action == .resolvedTap)
        }
    }

    // MARK: - Hold Trigger on Release

    @Test("Hold trigger on release: same-hand key down stays undecided")
    func holdTriggerOnReleaseSameHandDown() {
        let sm = makeMachine(bilateralFiltering: true, holdTriggerOnRelease: true)
        _ = sm.onPress(at: 1.0)

        let action = sm.onOtherKeyDown(hand: .left, at: 1.050)
        #expect(action == .none)
        #expect(sm.state == .undecided)
    }

    @Test("Hold trigger on release: same-hand key up stays undecided")
    func holdTriggerOnReleaseSameHandUp() {
        let sm = makeMachine(bilateralFiltering: true, holdTriggerOnRelease: true)
        _ = sm.onPress(at: 1.0)
        _ = sm.onOtherKeyDown(hand: .left, at: 1.050)

        let action = sm.onOtherKeyUp(hand: .left, at: 1.080)
        #expect(action == .none)
        #expect(sm.state == .undecided)
    }

    @Test("Hold trigger on release: opposite-hand key up resolves hold")
    func holdTriggerOnReleaseOppositeHandUp() {
        let sm = makeMachine(bilateralFiltering: true, holdTriggerOnRelease: true)
        _ = sm.onPress(at: 1.0)
        _ = sm.onOtherKeyDown(hand: .right, at: 1.050)

        let action = sm.onOtherKeyUp(hand: .right, at: 1.080)
        #expect(action == .resolvedHold)
        #expect(sm.state == .hold)
    }

    @Test("Hold trigger on release: neutral and unknown keys do not resolve hold")
    func holdTriggerOnReleaseNeutralAndUnknownKeysDoNotResolveHold() {
        for hand in [KeyHand.neutral, .unknown] {
            let sm = makeMachine(bilateralFiltering: true, holdTriggerOnRelease: true)
            _ = sm.onPress(at: 1.0)

            let action = sm.onOtherKeyUp(hand: hand, at: 1.080)
            #expect(action == .none)
            #expect(sm.state == .undecided)
        }
    }

    // MARK: - Edge Cases

    @Test("Other key events on idle state are no-op")
    func otherKeyOnIdleNoop() {
        let sm = makeMachine()
        let a1 = sm.onOtherKeyDown(hand: .unknown, at: 1.0)
        let a2 = sm.onOtherKeyUp(hand: .unknown, at: 1.0)
        #expect(a1 == .none)
        #expect(a2 == .none)
    }
}
