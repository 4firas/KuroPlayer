import SwiftUI
#if os(macOS)
import AppKit
#endif

struct HideScrollbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
#if os(macOS)
            .background(ScrollViewHider())
#endif
    }
}

extension View {
    /// Completely hides native macOS scrollbars by introspecting the enclosing NSScrollView.
    func hideNativeScrollbars() -> some View {
        self.modifier(HideScrollbarModifier())
    }
}

#if os(macOS)
struct ScrollViewHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.scrollerStyle = .overlay
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
