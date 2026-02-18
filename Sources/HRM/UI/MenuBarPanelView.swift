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

            if !appState.isAccessibilityGranted {
                Button("Grant Accessibility Permission") {
                    appState.requestAccessibility()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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
}
