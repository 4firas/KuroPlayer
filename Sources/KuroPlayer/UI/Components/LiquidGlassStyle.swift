import SwiftUI

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Glass Pressable (for non-Button click targets)

struct GlassPressableModifier: ViewModifier {
    @StateObject private var tracker = HoverPressTracker()
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(tracker.isDown ? 0.98 : 1.0)
            .opacity(tracker.isDown ? 0.8 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: tracker.isDown)
    }
}

class HoverPressTracker: ObservableObject {
    @Published var isDown = false
    
    func press() { isDown = true }
    func release() { isDown = false }
}

// MARK: - Glass Surface Modifier

struct GlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(KurokulaTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(KurokulaTheme.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Glass Material Background

struct GlassMaterialModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    KurokulaTheme.background
                    
                    // Subtle glass overlay
                    VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                        .opacity(0.7)
                }
            )
    }
}

// MARK: - macOS Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Convenience View Extensions

extension View {
    func liquidGlassButton() -> some View {
        self.buttonStyle(LiquidGlassButtonStyle())
    }
    
    func glassSurface(cornerRadius: CGFloat = 8) -> some View {
        self.modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }
    
    func glassPressable() -> some View {
        self.modifier(GlassPressableModifier())
    }
    
    func glassBackground() -> some View {
        self.modifier(GlassMaterialModifier())
    }
}
