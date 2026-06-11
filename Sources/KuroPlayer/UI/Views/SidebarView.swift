import SwiftUI

enum MainView: String, CaseIterable, Identifiable, Hashable {
    case home, search, library, queue, settings
    var id: String { rawValue }
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var authManager = AuthManager.shared
    
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
                ForEach(viewModel.playlists) { playlist in
                    Label(playlist.name, systemImage: "music.note")
                        .tag(MainView.home) // TODO: Navigate to playlist view
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
                Button {
                    viewModel.selectedView = .settings
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("KuroPlayer")
    }
}

struct ServiceIndicator: View {
    let name: String
    let icon: String
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(name)
            Spacer()
            Circle()
                .fill(isConnected ? KurokulaTheme.success : .secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .foregroundColor(isConnected ? .primary : .secondary)
    }
}
