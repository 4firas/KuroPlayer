import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedView: $viewModel.selectedView)
                .environmentObject(viewModel)
            
            VStack(spacing: 0) {
                ZStack {
                    switch viewModel.selectedView {
                    case .home:
                        HomeView()
                    case .search:
                        SearchView()
                    case .library:
                        LibraryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                PlayerBarView()
                    .environmentObject(viewModel)
            }
        }
        .environmentObject(viewModel)
        .frame(minWidth: 1000, minHeight: 600)
        .background(KurokulaTheme.background)
        .onAppear {
            Task {
                await viewModel.loadLibrary()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(KurokulaTheme.foreground)
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Start")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        HStack(spacing: 12) {
                            QuickActionButton(icon: "magnifyingglass", title: "Search", color: KurokulaTheme.accent)
                            QuickActionButton(icon: "music.note.list", title: "Library", color: KurokulaTheme.secondary)
                            QuickActionButton(icon: "waveform", title: "Radio", color: KurokulaTheme.success)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recently played
                    if !viewModel.libraryTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("From Your Library")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(KurokulaTheme.foreground)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.libraryTracks.prefix(10)) { track in
                                        TrackCard(track: track)
                                            .onTapGesture {
                                                viewModel.play(track: track)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Connected services status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connected Services")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        HStack(spacing: 12) {
                            ServiceStatusCard(
                                name: "YouTube Music",
                                icon: "play.rectangle",
                                isConnected: AuthManager.shared.isAuthenticatedYouTubeMusic
                            )
                            
                            ServiceStatusCard(
                                name: "SoundCloud",
                                icon: "cloud",
                                isConnected: AuthManager.shared.isAuthenticatedSoundCloud
                            )
                            
                            ServiceStatusCard(
                                name: "Last.fm",
                                icon: "waveform",
                                isConnected: AuthManager.shared.isAuthenticatedLastFm
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .background(KurokulaTheme.background)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(width: 100, height: 80)
            .glassSurface(cornerRadius: 8)
        }
        .buttonStyle(.borderless)
    }
}

struct TrackCard: View {
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: track.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(KurokulaTheme.gray.opacity(0.3))
            }
            .frame(width: 140, height: 140)
            .cornerRadius(4)
            
            Text(track.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KurokulaTheme.foreground)
                .lineLimit(1)
            
            Text(track.artist)
                .font(.caption2)
                .foregroundColor(KurokulaTheme.gray)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

struct ServiceStatusCard: View {
    let name: String
    let icon: String
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isConnected ? KurokulaTheme.success : KurokulaTheme.gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(KurokulaTheme.foreground)
                
                Text(isConnected ? "Connected" : "Not connected")
                    .font(.caption)
                    .foregroundColor(isConnected ? KurokulaTheme.success : KurokulaTheme.gray)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(KurokulaTheme.cardBackground)
        .cornerRadius(8)
    }
}
