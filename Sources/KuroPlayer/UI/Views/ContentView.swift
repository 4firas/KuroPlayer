import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
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
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .search:
                        SearchView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .library:
                        LibraryView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .settings:
                        SettingsView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .backgroundExtension()
                
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
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(KurokulaTheme.accent)
                    Text(errorMessage)
                        .foregroundColor(KurokulaTheme.foreground)
                    Spacer()
                    Button(action: { viewModel.dismissError() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(KurokulaTheme.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(KurokulaTheme.cardBackground)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if viewModel.errorMessage == errorMessage {
                            withAnimation {
                                viewModel.dismissError()
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: viewModel.errorMessage)
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
                            QuickActionButton(icon: "magnifyingglass", title: "Search", color: KurokulaTheme.accent) {
                                viewModel.selectedView = .search
                            }
                            QuickActionButton(icon: "music.note.list", title: "Library", color: KurokulaTheme.secondary) {
                                viewModel.selectedView = .library
                            }
                            QuickActionButton(icon: "waveform", title: "Radio", color: KurokulaTheme.success) {
                                // future feature
                            }
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
                                            .environmentObject(viewModel)
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        Button(action: {
            viewModel.play(track: track)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    AsyncImage(url: track.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Rectangle()
                                .fill(KurokulaTheme.gray.opacity(0.3))
                            Image(systemName: "music.note")
                                .foregroundColor(KurokulaTheme.gray)
                        }
                    }
                    .frame(width: 140, height: 140)
                    .cornerRadius(4)

                    if viewModel.currentTrack?.id == track.id {
                        NowPlayingIndicator(isPlaying: viewModel.isPlaying)
                            .frame(width: 140, height: 140)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
            
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
        .buttonStyle(.plain)
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
