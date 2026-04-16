import Foundation

struct KeyboardDevice: Codable, Equatable, Identifiable {
    let keyboardType: Int
    let name: String

    var id: Int { keyboardType }
}
