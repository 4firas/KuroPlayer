import SwiftUI

@main
struct KuroPlayerApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if let viewModel = appState.viewModel {
                ContentView()
                    .environmentObject(viewModel)
                    .transition(.opacity)
            } else {
                ProgressView("Loading KuroPlayer...")
                    .transition(.opacity)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 700)
        .onChange(of: appState.viewModel != nil) { _, isReady in
            if isReady {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Trigger view update
                }
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var viewModel: PlayerViewModel?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var engine: PlaybackEngine!
    var appState: AppState!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        
        Task { @MainActor in
            engine = PlaybackEngine()
            let vm = PlayerViewModel(playbackEngine: engine)
            
            MediaKeyHandler.shared.setup(engine: engine)

            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "KuroPlayer")
                button.action = #selector(togglePopover)
            }

            popover = NSPopover()
            popover.contentSize = NSSize(width: 250, height: 150)
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: MiniPlayerView().environmentObject(vm))
            
            // Set viewModel last to trigger UI update
            appState.viewModel = vm
        }
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
