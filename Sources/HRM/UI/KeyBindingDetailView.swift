import SwiftUI

struct KeyBindingDetailView: View {
    @Binding var binding: KeyBinding
    let config: Configuration
    var onChanged: () -> Void

    var body: some View {
        Form {
            Section("Key: \(binding.label)") {
                Toggle("Enabled", isOn: $binding.enabled)

                Picker("Modifier", selection: $binding.modifier) {
                    Text("None").tag(Modifier?.none)
                    ForEach(Modifier.allCases) { mod in
                        Text(mod.symbol + " " + mod.displayName).tag(Modifier?.some(mod))
                    }
                }

                Text("Position: \(binding.position.displayName)")
                    .foregroundStyle(.secondary)
            }

            Section("Bilateral Filtering") {
                overrideToggle(
                    label: "Bilateral Filtering",
                    value: $binding.bilateralFiltering,
                    globalDefault: config.bilateralFiltering
                )
            }

            Section("Timing Overrides") {
                overrideIntField(
                    label: "Quick Tap Term",
                    value: $binding.quickTapTermMs,
                    globalDefault: config.quickTapTermMs
                )

                overrideIntField(
                    label: "Require Prior Idle",
                    value: $binding.requirePriorIdleMs,
                    globalDefault: config.requirePriorIdleMs
                )
            }
        }
        .formStyle(.grouped)
        .onChange(of: binding) { onChanged() }
    }

    // MARK: - Override Helpers

    private func overrideToggle(label: String, value: Binding<Bool?>, globalDefault: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: value) {
                Text("Global (\(globalDefault ? "On" : "Off"))").tag(Bool?.none)
                Text("On").tag(Bool?.some(true))
                Text("Off").tag(Bool?.some(false))
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        }
    }

    private func overrideIntField(label: String, value: Binding<Int?>, globalDefault: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let val = value.wrappedValue {
                Stepper(value: Binding(
                    get: { val },
                    set: { value.wrappedValue = $0 }
                ), in: 0...999, step: 10) {
                    HStack {
                        Text(label)
                        Spacer()
                        TextField("ms", value: Binding(
                            get: { val },
                            set: { value.wrappedValue = $0 }
                        ), format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                        Text("ms")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Reset to Global") { value.wrappedValue = nil }
                    .font(.caption)
            } else {
                HStack {
                    Text(label)
                    Spacer()
                    Text("\(globalDefault)ms (global)")
                        .foregroundStyle(.secondary)
                    Button("Override") { value.wrappedValue = globalDefault }
                        .font(.caption)
                }
            }
        }
    }
}
