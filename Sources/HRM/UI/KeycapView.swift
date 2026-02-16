import SwiftUI

struct KeycapView: View {
    let binding: KeyBinding
    var onTap: () -> Void = {}

    @State private var isHovered = false

    private var modifierColor: Color {
        binding.enabled ? (binding.modifier?.themeColor ?? .gray) : .gray
    }

    private var isDisabled: Bool {
        !binding.enabled || binding.modifier == nil
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(binding.label)
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Text(binding.enabled ? (binding.modifier?.symbol ?? "--") : "--")
                .font(.system(size: 10))
                .foregroundStyle(isDisabled ? .secondary : modifierColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(modifierColor.opacity(isDisabled ? 0.1 : (isHovered ? 0.3 : 0.2)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(modifierColor.opacity(isDisabled ? 0.15 : 0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0), radius: 2, y: 1)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}
