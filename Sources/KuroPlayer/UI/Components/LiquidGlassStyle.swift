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

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Applies `.glassEffect(.regular.interactive(), in: .rect(cornerRadius:))` — the standard card pattern.
    func glassCard(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }
    
    /// Applies `.glassEffect(.regular, in: .rect(cornerRadius:))` — non-interactive glass surface.
    func glassSurface(cornerRadius: CGFloat = 12) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
