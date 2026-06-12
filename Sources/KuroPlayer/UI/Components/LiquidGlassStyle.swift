import SwiftUI

// MARK: - Liquid Glass Helpers
// 
// With macOS 26+ we use native APIs throughout:
// - .buttonStyle(.glass) / .buttonStyle(.glassProminent)
// - .glassEffect(_:in:) for custom surfaces
// - GlassEffectContainer for grouping/morphing
// - .backgroundExtensionEffect() for edge-to-edge content
//
// This file only contains KuroPlayer-specific helpers.

// MARK: - Glass Card Modifier
// Convenience wrapper for the most common glass pattern:
// a rounded-rect card with interactive glass.

struct FlatCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint ?? .primary.opacity(0.05))
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        modifier(FlatCard(cornerRadius: cornerRadius, tint: tint))
    }
    
    func glassSurface(cornerRadius: CGFloat = 12) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.primary.opacity(0.05))
        )
    }
}

class FlatButtonState: ObservableObject {
    @Published var isHovered = false
}

struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FlatButtonView(configuration: configuration)
    }
}

struct FlatButtonView: View {
    let configuration: ButtonStyle.Configuration
    @StateObject private var state = FlatButtonState()
    
    var body: some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : (state.isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(.rect)
            .onHover { h in state.isHovered = h }
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    static var flat: FlatButtonStyle { FlatButtonStyle() }
    static var glass: FlatButtonStyle { FlatButtonStyle() } // alias for existing references
}
