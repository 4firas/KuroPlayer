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
    class HiderView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            hideScrollers()
        }
        
        override func layout() {
            super.layout()
            hideScrollers()
        }
        
        private func hideScrollers() {
            if let scrollView = self.enclosingScrollView {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.scrollerStyle = .overlay
            }
        }
    }

    func makeNSView(context: Context) -> NSView {
        return HiderView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
