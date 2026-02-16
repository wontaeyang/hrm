struct Configuration: Codable, Equatable {
    var enabled: Bool
    var quickTapTermMs: Int
    var requirePriorIdleMs: Int
    var bilateralFiltering: Bool
    var holdTriggerOnRelease: Bool
    var keyBindings: [KeyBinding]

    func effectiveQuickTapTerm(for binding: KeyBinding) -> Int {
        binding.quickTapTermMs ?? quickTapTermMs
    }

    func effectiveRequirePriorIdle(for binding: KeyBinding) -> Int {
        binding.requirePriorIdleMs ?? requirePriorIdleMs
    }

    func effectiveBilateralFiltering(for binding: KeyBinding) -> Bool {
        binding.bilateralFiltering ?? bilateralFiltering
    }

    func binding(for keyCode: UInt16) -> KeyBinding? {
        keyBindings.first { $0.keyCode == keyCode && $0.enabled }
    }
}
