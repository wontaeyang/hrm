import SwiftUI

struct KeyBindingDetailView: View {
    @Binding var binding: KeyBinding
    let config: Configuration
    var onChanged: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.primary, .quaternary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                Text("Key: \(KeyCodeLabel.label(for: binding.keyCode))")
                    .font(.headline)

                Spacer()

                Text("Position: \(binding.position.displayName)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                groupedSection("Key Binding") {
                    groupedRow {
                        HStack {
                            Text(binding.enabled ? "Enabled" : "Disabled")
                            Spacer()
                            Toggle("", isOn: $binding.enabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                    Divider().padding(.leading, 16)
                    groupedRow {
                        HStack {
                            Text("Modifier")
                            Spacer()
                            Picker("", selection: $binding.modifier) {
                                Text("None").tag(Modifier?.none)
                                ForEach(Modifier.allCases) { mod in
                                    Text(mod.symbol + " " + mod.displayName).tag(Modifier?.some(mod))
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                groupedSection("Bilateral Filtering") {
                    groupedRow {
                        overrideToggle(
                            label: "Bilateral Filtering",
                            value: $binding.bilateralFiltering,
                            globalDefault: config.bilateralFiltering
                        )
                    }
                }

                groupedSection("Timing Overrides") {
                    groupedRow {
                        overrideIntField(
                            label: "Quick Tap Term",
                            value: $binding.quickTapTermMs,
                            globalDefault: config.quickTapTermMs
                        )
                    }
                    Divider().padding(.leading, 16)
                    groupedRow {
                        overrideIntField(
                            label: "Require Prior Idle",
                            value: $binding.requirePriorIdleMs,
                            globalDefault: config.requirePriorIdleMs
                        )
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .onChange(of: binding) { onChanged() }
    }

    // MARK: - Grouped Style Helpers

    private func groupedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    }

    private func groupedRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
            .fixedSize()
        }
    }

    private func overrideIntField(label: String, value: Binding<Int?>, globalDefault: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let val = value.wrappedValue {
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
                    Stepper("", value: Binding(
                        get: { val },
                        set: { value.wrappedValue = $0 }
                    ), in: 0...999, step: 10)
                    .labelsHidden()
                    .fixedSize()
                    Button("Reset") { value.wrappedValue = nil }
                        .font(.caption)
                }
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
