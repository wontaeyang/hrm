import ServiceManagement
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appState: AppState
    @State private var selectedKeyIndex: Int?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if let version = appState.availableUpdate {
                    updateBanner(version: version)
                }
                Divider()
                scrollContent
                Divider()
                footer
            }
            .navigationDestination(for: Int.self) { index in
                KeyBindingDetailView(
                    binding: Binding(
                        get: { appState.configuration.keyBindings[index] },
                        set: { appState.configuration.keyBindings[index] = $0 }
                    ),
                    config: appState.configuration,
                    onChanged: { appState.saveAndApply() }
                )
            }
        }
        .frame(width: 400)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HRM")
                    .font(.headline)
                Spacer()
                Toggle(appState.isEnabled ? "Enabled" : "Disabled", isOn: Binding(
                    get: { appState.isEnabled },
                    set: { appState.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .fixedSize()
            }

            permissionStatus

            if appState.eventTapFailed {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Event tap failed to start", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Remove HRM from Accessibility and Input Monitoring in System Settings, restart the app, and re-grant permissions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open Privacy Settings") { openPrivacySettings() }
                        Button("Retry") {
                            appState.stopEventTap()
                            appState.startEventTap()
                        }
                    }
                    .controlSize(.small)
                }
            }

            if appState.eventTapDegraded {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Keyboard events not received — permissions may be stale", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Remove HRM from both Accessibility and Input Monitoring, restart the app, and re-grant permissions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings") { openPrivacySettings() }
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Permission Status

    @ViewBuilder
    private var permissionStatus: some View {
        let axOK = appState.isAccessibilityGranted
        let imOK = appState.isInputMonitoringGranted

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: axOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(axOK ? .green : .red)
                Text("Accessibility")
                    .font(.caption)
                Spacer()
                Image(systemName: imOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(imOK ? .green : .red)
                Text("Input Monitoring")
                    .font(.caption)
            }

            if !axOK || !imOK {
                HStack {
                    Button("Grant Permissions") {
                        appState.requestPermissions()
                    }
                    Button("Open Privacy Settings") { openPrivacySettings() }
                }
                .controlSize(.small)
            }
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Update Banner

    private func updateBanner(version: String) -> some View {
        HStack {
            Text("Version \(version) available")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Download") {
                if let url = URL(string: "https://github.com/wontaeyang/hrm/releases/latest") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.body)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.quaternary)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                keyboardSection
                Divider()
                settingsSection
            }
            .padding()
        }
    }

    // MARK: - Keyboard Section

    private var keyboardSection: some View {
        KeyboardRowView(bindings: appState.configuration.keyBindings) { index in
            selectedKeyIndex = index
        }
        .navigationDestination(item: $selectedKeyIndex) { index in
            KeyBindingDetailView(
                binding: Binding(
                    get: { appState.configuration.keyBindings[index] },
                    set: { appState.configuration.keyBindings[index] = $0 }
                ),
                config: appState.configuration,
                onChanged: { appState.saveAndApply() }
            )
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.headline)

            settingToggle("Launch at Login", isOn: launchAtLoginBinding)

            settingToggle("Caps Lock → Backspace", isOn: capsLockRemapBinding)

            settingToggle("Bilateral Filtering", isOn: bilateralFilteringBinding)

            HStack {
                Text("Permissive Hold")
                    .font(.body)
                Spacer()
                Picker("", selection: holdTriggerOnReleaseBinding) {
                    Text("Key Down").tag(false)
                    Text("Key Up").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .labelsHidden()
            }
            .opacity(appState.configuration.bilateralFiltering ? 1 : 0.4)
            .disabled(!appState.configuration.bilateralFiltering)
            msStepper("Quick Tap Term", value: quickTapTermBinding)
            msStepper("Require Prior Idle", value: requirePriorIdleBinding)

            HStack {
                Text("Keyboard")
                    .font(.body)
                Spacer()
                Picker("", selection: selectedKeyboardBinding) {
                    Text("All Keyboards").tag(Int?.none)
                    ForEach(appState.keyboardMonitor.discoveredKeyboards) { keyboard in
                        Text(keyboard.name).tag(Int?.some(keyboard.keyboardType))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .labelsHidden()
            }
        }
    }

    private func settingToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .fixedSize()
        }
    }

    private func msStepper(_ label: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...999, step: 10) {
            HStack {
                Text(label)
                    .font(.body)
                Spacer()
                TextField("ms", value: value, format: .number)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                Text("ms")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Reset to Defaults") {
                appState.configuration = DefaultConfiguration.make()
                appState.saveAndApply()
            }
            .controlSize(.small)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Bindings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                try? newValue
                    ? SMAppService.mainApp.register()
                    : SMAppService.mainApp.unregister()
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        )
    }

    private var capsLockRemapBinding: Binding<Bool> {
        Binding(
            get: { appState.configuration.remapCapsLockToBackspace },
            set: {
                appState.configuration.remapCapsLockToBackspace = $0
                appState.saveAndApply()
            }
        )
    }

    private var bilateralFilteringBinding: Binding<Bool> {
        Binding(
            get: { appState.configuration.bilateralFiltering },
            set: {
                appState.configuration.bilateralFiltering = $0
                appState.saveAndApply()
            }
        )
    }

    private var holdTriggerOnReleaseBinding: Binding<Bool> {
        Binding(
            get: { appState.configuration.holdTriggerOnRelease },
            set: {
                appState.configuration.holdTriggerOnRelease = $0
                appState.saveAndApply()
            }
        )
    }

    private var quickTapTermBinding: Binding<Int> {
        Binding(
            get: { appState.configuration.quickTapTermMs },
            set: {
                appState.configuration.quickTapTermMs = $0
                appState.saveAndApply()
            }
        )
    }

    private var requirePriorIdleBinding: Binding<Int> {
        Binding(
            get: { appState.configuration.requirePriorIdleMs },
            set: {
                appState.configuration.requirePriorIdleMs = $0
                appState.saveAndApply()
            }
        )
    }

    private var selectedKeyboardBinding: Binding<Int?> {
        Binding(
            get: { appState.configuration.selectedKeyboard?.keyboardType },
            set: { newType in
                if let type = newType,
                   let device = appState.keyboardMonitor.discoveredKeyboards.first(where: { $0.keyboardType == type })
                {
                    appState.configuration.selectedKeyboard = device
                } else {
                    appState.configuration.selectedKeyboard = nil
                }
                appState.saveAndApply()
            }
        )
    }
}
