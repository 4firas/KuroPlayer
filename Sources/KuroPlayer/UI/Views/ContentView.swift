import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Main content area with background extension
                ZStack {
                    switch viewModel.selectedView {
                    case .home:
                        HomeView()
                    case .search:
                        SearchView()
                    case .library:
                        LibraryView()
                    case .queue:
                        QueueView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .backgroundExtensionEffect()
                
                // Player bar
                PlayerBarView()
                    .environmentObject(viewModel)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(viewModel)
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear {
            Task {
                await viewModel.loadLibrary()
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage) {
                    withAnimation {
                        viewModel.dismissError()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.errorMessage)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                onDismiss()
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Hero section with background extension
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [KurokulaTheme.accent.opacity(0.3), KurokulaTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("What do you want to play?")
                            .font(.largeTitle.bold())
                    }
                    .padding(24)
                }
                .backgroundExtensionEffect()
                
                // Quick actions with glass
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Start")
                        .font(.title2.bold())
                    
                    GlassEffectContainer(spacing: 16) {
                        HStack(spacing: 16) {
                            QuickActionButton(icon: "magnifyingglass", title: "Search", tint: KurokulaTheme.accent) {
                                viewModel.selectedView = .search
                            }
                            QuickActionButton(icon: "music.note.list", title: "Library", tint: KurokulaTheme.secondary) {
                                viewModel.selectedView = .library
                            }
                            QuickActionButton(icon: "list.bullet", title: "Queue", tint: KurokulaTheme.success) {
                                viewModel.selectedView = .queue
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Recently played
                if !viewModel.libraryTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("From Your Library")
                            .font(.title2.bold())
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.libraryTracks.prefix(10)) { track in
                                    TrackCard(track: track)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                
                // Services status
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connected Services")
                        .font(.title2.bold())
                    
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Space for player bar
            }
        }
    }
}

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
            .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                            Color.gray.opacity(0.2)
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(.rect(cornerRadius: 12))
                    
                    if viewModel.currentTrack?.id == track.id {
                        NowPlayingIndicator(isPlaying: viewModel.isPlaying)
                            .frame(width: 160, height: 160)
                            .background(.black.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}

struct ServiceStatusCard: View {
    let name: String
    let icon: String
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isConnected ? KurokulaTheme.success : .secondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(isConnected ? "Connected" : "Not connected")
                    .font(.caption)
                    .foregroundColor(isConnected ? KurokulaTheme.success : .secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(isConnected ? KurokulaTheme.success : .secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}
