import Foundation

/// Discovers keyboards by observing keyboardEventKeyboardType values from CGEvent.
/// No extra permissions required beyond the existing Accessibility permission.
final class KeyboardMonitor: ObservableObject {
    @Published var discoveredKeyboards: [KeyboardDevice] = []

    private let lock = NSLock()
    private var observedTypes: Set<Int> = []

    /// Called from the event tap thread when a key event is processed.
    func recordKeyboardType(_ type: Int) {
        lock.lock()
        let isNew = observedTypes.insert(type).inserted
        lock.unlock()

        if isNew {
            DispatchQueue.main.async { [weak self] in
                self?.rebuildList()
            }
        }
    }

    private func rebuildList() {
        lock.lock()
        let types = observedTypes
        lock.unlock()

        discoveredKeyboards = types
            .map { KeyboardDevice(keyboardType: $0) }
            .sorted { $0.name < $1.name }
    }
}
