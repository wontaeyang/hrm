struct KeyBinding: Codable, Identifiable, Equatable {
    var id: UInt16 { keyCode }
    let keyCode: UInt16
    let label: String
    var modifier: Modifier?
    var enabled: Bool
    let position: KeyPosition

    // Per-key overrides (nil = use global defaults)
    var quickTapTermMs: Int?
    var requirePriorIdleMs: Int?
    var bilateralFiltering: Bool?
}
