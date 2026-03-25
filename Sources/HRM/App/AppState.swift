import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var configuration: Configuration
    @Published var isAccessibilityGranted = false
    @Published var availableUpdate: String?

    private let store = ConfigurationStore()
    private var engine: TapHoldEngine
    private var eventTapManager: EventTapManager?
    private var hasLaunched = false

    var isEnabled: Bool {
        get { configuration.enabled }
        set {
            configuration.enabled = newValue
            saveAndApply()
        }
    }

    init() {
        let config = store.load()
        self.configuration = config
        self.engine = TapHoldEngine(config: config)

        // Defer startup to after SwiftUI scene is ready
        Task { @MainActor [weak self] in
            self?.performStartup()
        }
    }

    private func performStartup() {
        guard !hasLaunched else { return }
        hasLaunched = true

        Task { [weak self] in
            let update = await UpdateChecker.check()
            self?.availableUpdate = update
        }

        checkAccessibility()
        if isAccessibilityGranted {
            startEventTap()
        } else {
            requestAccessibility()
        }
    }

    func startEventTap() {
        guard eventTapManager == nil else { return }
        let manager = EventTapManager(engine: engine)
        self.eventTapManager = manager
        if configuration.enabled {
            manager.start()
        }
    }

    func stopEventTap() {
        eventTapManager?.stop()
        eventTapManager = nil
    }

    func saveAndApply() {
        try? store.save(configuration)
        engine.updateConfig(configuration)

        if configuration.enabled {
            if eventTapManager?.isRunning == false {
                eventTapManager?.start()
            }
        } else {
            eventTapManager?.stop()
        }
    }

    func checkAccessibility() {
        isAccessibilityGranted = AccessibilityManager.isTrusted
    }

    func requestAccessibility() {
        AccessibilityManager.ensureAccessibility { [weak self] granted in
            Task { @MainActor in
                self?.isAccessibilityGranted = granted
                if granted {
                    self?.startEventTap()
                }
            }
        }
    }
}
