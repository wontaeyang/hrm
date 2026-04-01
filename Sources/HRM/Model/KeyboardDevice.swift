struct KeyboardDevice: Codable, Equatable, Hashable, Identifiable {
    let keyboardType: Int

    var id: Int { keyboardType }

    var name: String {
        switch keyboardType {
        case 59: return "Built-in Keyboard (ANSI)"
        case 60: return "Built-in Keyboard (ISO)"
        case 61: return "Built-in Keyboard (JIS)"
        case 40: return "Apple External (ANSI)"
        case 41: return "Apple External (ISO)"
        case 42: return "Apple External (JIS)"
        default: return "Keyboard (Type \(keyboardType))"
        }
    }
}
