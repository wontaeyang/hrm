enum KeyPosition: String, Codable, CaseIterable, Identifiable {
    case leftPinky
    case leftRing
    case leftMiddle
    case leftIndex
    case leftIndexInner
    case rightIndexInner
    case rightIndex
    case rightMiddle
    case rightRing
    case rightPinky

    var id: String { rawValue }

    var hand: Hand {
        switch self {
        case .leftPinky, .leftRing, .leftMiddle, .leftIndex, .leftIndexInner:
            return .left
        case .rightIndexInner, .rightIndex, .rightMiddle, .rightRing, .rightPinky:
            return .right
        }
    }

    var displayName: String {
        switch self {
        case .leftPinky: "Left Pinky"
        case .leftRing: "Left Ring"
        case .leftMiddle: "Left Middle"
        case .leftIndex: "Left Index"
        case .leftIndexInner: "Left Index (Inner)"
        case .rightIndexInner: "Right Index (Inner)"
        case .rightIndex: "Right Index"
        case .rightMiddle: "Right Middle"
        case .rightRing: "Right Ring"
        case .rightPinky: "Right Pinky"
        }
    }

    enum Hand: String, Codable {
        case left
        case right

        var opposite: Hand {
            switch self {
            case .left: .right
            case .right: .left
            }
        }
    }
}
