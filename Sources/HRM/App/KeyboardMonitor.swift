import Combine
import Foundation

@MainActor
final class KeyboardMonitor: ObservableObject {
    @Published private(set) var discoveredKeyboards: [KeyboardDevice] = []
    private var seenTypes: Set<Int> = []

    nonisolated func recordKeyboardType(_ type: Int) {
        Task { @MainActor in
            guard !seenTypes.contains(type) else { return }
            seenTypes.insert(type)
            let name = "Keyboard (type \(type))"
            discoveredKeyboards.append(KeyboardDevice(keyboardType: type, name: name))
        }
    }
}
