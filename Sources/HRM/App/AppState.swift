import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var configuration: Configuration
    @Published var isAccessibilityGranted = false
    @Published var isInputMonitoringGranted = false
    @Published var eventTapFailed = false
    @Published var eventTapDegraded = false
    @Published var availableUpdate: String?

    let keyboardMonitor = KeyboardMonitor()

    private let store = ConfigurationStore()
    private var engine: TapHoldEngine
    private var eventTapManager: EventTapManager?
    private var hasLaunched = false
    private var monitorCancellable: AnyCancellable?
    private var permissionTimer: Timer?

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

        // Forward keyboard monitor changes to trigger UI updates
        monitorCancellable = keyboardMonitor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

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

        checkPermissions()
        startPermissionPolling()
        if AccessibilityManager.hasAllPermissions {
            startEventTap()
        } else {
            requestPermissions()
        }
    }

    func startEventTap() {
        guard eventTapManager == nil else { return }
        let manager = EventTapManager(engine: engine)
        manager.keyboardMonitor = keyboardMonitor
        manager.setSelectedKeyboard(configuration.selectedKeyboard)
        manager.setRemapCapsLockToBackspace(configuration.remapCapsLockToBackspace)
        manager.onEventTapFailed = { [weak self] in
            self?.eventTapFailed = true
        }
        manager.onEventTapDegraded = { [weak self] in
            self?.eventTapDegraded = true
        }
        self.eventTapManager = manager
        eventTapFailed = false
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
        eventTapManager?.setSelectedKeyboard(configuration.selectedKeyboard)
        eventTapManager?.setRemapCapsLockToBackspace(configuration.remapCapsLockToBackspace)

        if configuration.enabled {
            if eventTapManager?.isRunning == false {
                eventTapManager?.start()
            }
        } else {
            eventTapManager?.stop()
        }
    }

    func checkPermissions() {
        isAccessibilityGranted = AccessibilityManager.isTrusted
        isInputMonitoringGranted = AccessibilityManager.isInputMonitoringGranted
    }

    /// Periodically re-check permissions so the UI stays up to date
    func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    func requestPermissions() {
        AccessibilityManager.ensureAllPermissions { [weak self] granted in
            Task { @MainActor in
                self?.isAccessibilityGranted = AccessibilityManager.isTrusted
                self?.isInputMonitoringGranted = AccessibilityManager.isInputMonitoringGranted
                if granted {
                    self?.startEventTap()
                }
            }
        }
    }
}
