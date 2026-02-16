import SwiftUI

struct KeyboardRowView: View {
    let bindings: [KeyBinding]
    var onSelectKey: (Int) -> Void = { _ in }

    private var leftHand: [KeyBinding] {
        bindings.filter { $0.position.hand == .left }
    }

    private var rightHand: [KeyBinding] {
        bindings.filter { $0.position.hand == .right }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key Bindings")
                .font(.headline)

            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(leftHand) { binding in
                        keycap(binding)
                    }

                    Rectangle()
                        .fill(.primary.opacity(0.6))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 2)

                    ForEach(rightHand) { binding in
                        keycap(binding)
                    }
                }

                HStack(spacing: 3) {
                    Text("Left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    Text("Right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            legend
        }
    }

    private func keycap(_ binding: KeyBinding) -> some View {
        KeycapView(binding: binding) {
            if let idx = bindings.firstIndex(where: { $0.keyCode == binding.keyCode }) {
                onSelectKey(idx)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Modifier.allCases) { mod in
                HStack(spacing: 3) {
                    Circle()
                        .fill(mod.themeColor)
                        .frame(width: 6, height: 6)
                    Text(mod.symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
