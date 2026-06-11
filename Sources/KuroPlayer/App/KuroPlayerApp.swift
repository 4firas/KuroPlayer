import SwiftUI

@main
struct KuroPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if let viewModel = appDelegate.viewModel {
                ContentView()
                    .environmentObject(viewModel)
            } else {
                ProgressView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 700)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var engine: PlaybackEngine!
    var viewModel: PlayerViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = PlaybackEngine()
        viewModel = PlayerViewModel(playbackEngine: engine)

        MediaKeyHandler.shared.setup(engine: engine)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "KuroPlayer")
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 150)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MiniPlayerView(viewModel: viewModel))
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
