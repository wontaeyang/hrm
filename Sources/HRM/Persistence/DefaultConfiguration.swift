enum DefaultConfiguration {
    static func make() -> Configuration {
        Configuration(
            enabled: true,
            quickTapTermMs: 150,
            requirePriorIdleMs: 150,
            bilateralFiltering: true,
            holdTriggerOnRelease: true,
            keyBindings: defaultKeyBindings,
            remapCapsLockToBackspace: false
        )
    }

    static let defaultKeyBindings: [KeyBinding] = [
        KeyBinding(keyCode: 0x00, modifier: .control, enabled: true, position: .leftPinky),
        KeyBinding(keyCode: 0x01, modifier: .option, enabled: true, position: .leftRing),
        KeyBinding(keyCode: 0x02, modifier: .command, enabled: true, position: .leftMiddle),
        KeyBinding(keyCode: 0x03, modifier: .shift, enabled: true, position: .leftIndex),
        KeyBinding(keyCode: 0x05, modifier: nil, enabled: false, position: .leftIndexInner),
        KeyBinding(keyCode: 0x04, modifier: nil, enabled: false, position: .rightIndexInner),
        KeyBinding(keyCode: 0x26, modifier: .shift, enabled: true, position: .rightIndex),
        KeyBinding(keyCode: 0x28, modifier: .command, enabled: true, position: .rightMiddle),
        KeyBinding(keyCode: 0x25, modifier: .option, enabled: true, position: .rightRing),
        KeyBinding(keyCode: 0x29, modifier: .control, enabled: true, position: .rightPinky),
    ]
}
