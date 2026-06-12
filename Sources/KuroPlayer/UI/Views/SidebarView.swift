import SwiftUI

enum MainView: Hashable, Identifiable {
    case home
    case search
    case library
    case playlists
    case queue
    case settings
    case playlist(String)

    var id: String {
        switch self {
        case .home: return "home"
        case .search: return "search"
        case .library: return "library"
        case .playlists: return "playlists"
        case .queue: return "queue"
        case .settings: return "settings"
        case .playlist(let playlistID): return "playlist-\(playlistID)"
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var playlistStore = PlaylistStore.shared
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List(selection: $viewModel.selectedView) {
            Section {
                Label("Home", systemImage: "house.fill")
                    .tag(MainView.home)

                Label("Search", systemImage: "magnifyingglass")
                    .tag(MainView.search)

                Label("Library", systemImage: "music.note.list")
                    .tag(MainView.library)

                Label("Queue", systemImage: "list.bullet")
                    .tag(MainView.queue)
            }

            Section("Playlists") {
                Label("All Playlists", systemImage: "square.grid.2x2")
                    .tag(MainView.playlists)

                ForEach(playlistStore.playlists) { playlist in
                    Label {
                        Text(playlist.name)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: playlist.providerType?.iconName ?? "music.note")
                    }
                    .tag(MainView.playlist(playlist.id))
                    .contextMenu {
                        Button("Remove Playlist", role: .destructive) {
                            viewModel.removePlaylist(playlist)
                        }
                    }
                }
            }

            Section("Connected") {
                ServiceIndicator(
                    name: "YouTube Music",
                    icon: "play.rectangle",
                    isConnected: authManager.isAuthenticatedYouTubeMusic
                )

                ServiceIndicator(
                    name: "SoundCloud",
                    icon: "cloud",
                    isConnected: authManager.isAuthenticatedSoundCloud
                )

                ServiceIndicator(
                    name: "Last.fm",
                    icon: "waveform",
                    isConnected: authManager.isAuthenticatedLastFm
                )
            }

            Section {
                Label("Settings", systemImage: "gear")
                    .tag(MainView.settings)
            }
        }
        .listStyle(.sidebar)
        .scrollIndicators(.hidden)
        .navigationTitle("KuroPlayer")
    }
}

struct ServiceIndicator: View {
    let name: String
    let icon: String
    let isConnected: Bool

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(name)
            Spacer()
            Circle()
                .fill(isConnected ? theme.success : .secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .foregroundColor(isConnected ? .primary : .secondary)
    }
}
