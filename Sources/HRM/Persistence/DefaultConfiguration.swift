enum DefaultConfiguration {
    static func make() -> Configuration {
        Configuration(
            enabled: true,
            quickTapTermMs: 150,
            requirePriorIdleMs: 150,
            bilateralFiltering: true,
            holdTriggerOnRelease: false,
            keyBindings: defaultKeyBindings
        )
    }

    static let defaultKeyBindings: [KeyBinding] = [
        KeyBinding(keyCode: 0x00, label: "A", modifier: .control, enabled: true, position: .leftPinky),
        KeyBinding(keyCode: 0x01, label: "S", modifier: .option, enabled: true, position: .leftRing),
        KeyBinding(keyCode: 0x02, label: "D", modifier: .command, enabled: true, position: .leftMiddle),
        KeyBinding(keyCode: 0x03, label: "F", modifier: .shift, enabled: true, position: .leftIndex),
        KeyBinding(keyCode: 0x05, label: "G", modifier: nil, enabled: false, position: .leftIndexInner),
        KeyBinding(keyCode: 0x04, label: "H", modifier: nil, enabled: false, position: .rightIndexInner),
        KeyBinding(keyCode: 0x26, label: "J", modifier: .shift, enabled: true, position: .rightIndex),
        KeyBinding(keyCode: 0x28, label: "K", modifier: .command, enabled: true, position: .rightMiddle),
        KeyBinding(keyCode: 0x25, label: "L", modifier: .option, enabled: true, position: .rightRing),
        KeyBinding(keyCode: 0x29, label: ";", modifier: .control, enabled: true, position: .rightPinky),
    ]
}
