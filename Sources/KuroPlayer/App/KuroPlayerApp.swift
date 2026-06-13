import SwiftUI
import AppKit

extension NSScrollView {
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.hasVerticalScroller = false
        self.hasHorizontalScroller = false
        self.scrollerStyle = .overlay
    }
}
import SwiftUI

@main
struct KuroPlayerApp: App {
    @StateObject private var viewModel: PlayerViewModel
    private let playbackEngine: PlaybackEngine

    init() {
        let engine = PlaybackEngine()
        self.playbackEngine = engine
        self._viewModel = StateObject(wrappedValue: PlayerViewModel(playbackEngine: engine))
        MediaKeyHandler.shared.setup(engine: engine)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .frame(minWidth: 900, minHeight: 580)
                .onAppear {
                    Task { await viewModel.loadLibrary() }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Search…") {
                    viewModel.selectedView = .search
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        // Menu bar mini player
        MenuBarExtra("KuroPlayer", systemImage: "music.note") {
            MiniPlayerView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .menuBarExtraStyle(.window)
    }
}
