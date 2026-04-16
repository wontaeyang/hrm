struct KeyBinding: Codable, Identifiable, Equatable {
    var id: String { position.rawValue }
    let keyCode: UInt16
    var modifier: Modifier?
    var enabled: Bool
    let position: KeyPosition

    // Per-key overrides (nil = use global defaults)
    var quickTapTermMs: Int?
    var requirePriorIdleMs: Int?
    var bilateralFiltering: Bool?

    private enum CodingKeys: String, CodingKey {
        case keyCode, modifier, enabled, position
        case quickTapTermMs, requirePriorIdleMs, bilateralFiltering
    }
}
