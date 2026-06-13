import SwiftUI
import AppKit

// MARK: - Content View
//
// Custom sidebar + detail layout. Sidebar sits flush next to the content.
// Player bar floats at the bottom spanning the full content width.

class ContentViewState: ObservableObject {
    @Published var sidebarWidth: CGFloat = 220
    @Published var isDraggingSidebar = false
}

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var state = ContentViewState()

    private let minSidebar: CGFloat = 180
    private let maxSidebar: CGFloat = 320

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                // Sidebar
                SidebarView()
                    .environmentObject(viewModel)
                    .frame(width: state.sidebarWidth)
                    .background(.thinMaterial)

                // Resize handle
                Rectangle()
                    .fill(.clear)
                    .frame(width: 4)
                    .contentShape(.rect)
                    .onHover { state.isDraggingSidebar = $0 }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                state.sidebarWidth = max(minSidebar, min(maxSidebar, state.sidebarWidth + value.translation.width))
                            }
                    )
                    .cursor(state.isDraggingSidebar ? .resizeLeftRight : .arrow)

                // Detail content
                VStack(spacing: 0) {
                    ZStack {
                        switch viewModel.selectedView {
                        case .home:
                            HomeView()
                        case .search:
                            SearchView()
                        case .library:
                            LibraryView()
                        case .lyrics:
                            LyricsView()
                        case .queue:
                            QueueView()
                        case .likedSongs:
                            LikedSongsView()
                        case .settings:
                            SettingsView()
                        case .playlistDetail:
                            PlaylistDetailView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .animation(.smooth(duration: 0.2), value: viewModel.selectedView)

                    // Player bar
                    PlayerBarView()
                        .environmentObject(viewModel)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Error banner
            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage) {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.dismissError()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            
            // MARK: Custom Overlays
            
            if viewModel.showNewPlaylist {
                KuroAlert(
                    title: "New Playlist",
                    placeholder: "Playlist name",
                    text: $viewModel.newPlaylistName,
                    primaryButtonTitle: "Create",
                    primaryAction: {
                        let name = viewModel.newPlaylistName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty {
                            viewModel.createPlaylist(name: name)
                        }
                        viewModel.newPlaylistName = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showNewPlaylist = false
                        }
                    },
                    cancelAction: {
                        viewModel.newPlaylistName = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showNewPlaylist = false
                        }
                    }
                )
                .zIndex(100)
            }
            
            if viewModel.showImportPlaylist {
                KuroAlert(
                    title: "Import Playlist",
                    placeholder: "SoundCloud or YouTube Music URL",
                    text: $viewModel.importPlaylistURL,
                    primaryButtonTitle: "Import",
                    primaryAction: {
                        let url = viewModel.importPlaylistURL.trimmingCharacters(in: .whitespaces)
                        if !url.isEmpty {
                            viewModel.importPlaylist(from: url)
                        }
                        viewModel.importPlaylistURL = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showImportPlaylist = false
                        }
                    },
                    cancelAction: {
                        viewModel.importPlaylistURL = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showImportPlaylist = false
                        }
                    }
                )
                .zIndex(100)
            }
            
            if viewModel.renamingPlaylistId != nil {
                KuroAlert(
                    title: "Rename Playlist",
                    placeholder: "New name",
                    text: $viewModel.renameText,
                    primaryButtonTitle: "Rename",
                    primaryAction: {
                        if let id = viewModel.renamingPlaylistId {
                            let name = viewModel.renameText.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty {
                                viewModel.renamePlaylist(id: id, name: name)
                            }
                        }
                        viewModel.renameText = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.renamingPlaylistId = nil
                        }
                    },
                    cancelAction: {
                        viewModel.renameText = ""
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.renamingPlaylistId = nil
                        }
                    }
                )
                .zIndex(100)
            }
        }
        .environmentObject(viewModel)
        .animation(.smooth(duration: 0.3), value: viewModel.errorMessage)
        .background(WindowAccessor())
        .onAppear {
            setupKeyboardMonitors()
        }
    }
    
    private func setupKeyboardMonitors() {
        // Space bar for Play/Pause
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Spacebar is keyCode 49
            if event.keyCode == 49 {
                // Ensure we aren't typing in a text field
                if let responder = NSApp.keyWindow?.firstResponder {
                    if responder.isKind(of: NSTextView.self) || responder.isKind(of: NSTextField.self) {
                        return event
                    }
                }
                Task { try? await viewModel.togglePlayPause() }
                return nil // consume event
            }
            return event
        }
        
        // System media keys when app is in focus (if MPRemoteCommandCenter isn't active)
        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
            if event.subtype.rawValue == 8 { // Media key event
                let keyCode = (event.data1 & 0xFFFF0000) >> 16
                let keyFlags = event.data1 & 0x0000FFFF
                let isPressed = (((keyFlags & 0xFF00) >> 8) == 0xA)
                
                if isPressed {
                    switch keyCode {
                    case 16: // Play/Pause
                        Task { try? await viewModel.togglePlayPause() }
                        return nil
                    case 17: // Next
                        Task { try? await viewModel.next() }
                        return nil
                    case 18: // Previous
                        Task { try? await viewModel.previous() }
                        return nil
                    default:
                        break
                    }
                }
            }
            return event
        }
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.titlebarSeparatorStyle = .none
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Cursor modifier

private struct CursorModifier: ViewModifier {
    let cursor: NSCursor

    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside { cursor.push() }
            else { NSCursor.pop() }
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.error)
            Text(message)
                .foregroundColor(.primary)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.smooth(duration: 0.25)) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Namespace private var nowPlayingNamespace

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                Text(viewModel.playlists.isEmpty ? "Welcome back" : "My Playlists")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)

                // Playlists grid
                if !viewModel.playlists.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16, alignment: .top)
                        ],
                        spacing: 20
                    ) {
                        ForEach(viewModel.playlists) { playlist in
                            let track = playlist.tracks.first
                            PlaylistCard(
                                title: playlist.name,
                                subtitle: track.flatMap { "\($0.artist) · \(playlist.trackCount) songs" }
                                    ?? "\(playlist.trackCount) songs",
                                artworkURL: track?.artworkURL,
                                fallbackSymbol: "music.note.list",
                                fallbackTint: Theme.accent,
                                isExplicit: false,
                                trackCount: playlist.trackCount,
                                isPlaying: viewModel.currentTrack?.id == track?.id && viewModel.isPlaying
                            )
                            .onTapGesture {
                                viewModel.selectedPlaylistId = playlist.id
                                viewModel.selectedView = .playlistDetail
                            }
                            // removed glassEffectID
                        }
                    }
                }

                // Quick Start
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Start")
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        QuickActionButton(icon: "magnifyingglass", title: "Search", tint: Theme.accent) {
                            viewModel.selectedView = .search
                        }
                        QuickActionButton(icon: "music.note.list", title: "Library", tint: Theme.accent) {
                            viewModel.selectedView = .library
                        }
                        QuickActionButton(icon: "list.bullet", title: "Queue", tint: Theme.accent) {
                            viewModel.selectedView = .queue
                        }
                        QuickActionButton(icon: "gearshape.fill", title: "Settings", tint: Theme.accent) {
                            viewModel.selectedView = .settings
                        }
                    }
                }

                // yt-dlp status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Streaming")
                        .font(.title2.bold())

                    HStack {
                        Image(systemName: YtDlp.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(YtDlp.isAvailable ? Theme.success : Theme.error)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("yt-dlp")
                                .font(.system(size: 14, weight: .semibold))
                            Text(YtDlp.isAvailable ? "Installed — YouTube Music & SoundCloud are ready" : "Not found — Install via: brew install yt-dlp")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
