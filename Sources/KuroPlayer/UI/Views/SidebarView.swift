import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Binding var selectedView: MainView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo/Title
            HStack {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(KurokulaTheme.secondary)
                Text("KuroPlayer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(KurokulaTheme.foreground)
            }
            .padding()
            
            Divider()
                .background(KurokulaTheme.gray)
            
            // Navigation
            VStack(alignment: .leading, spacing: 4) {
                SidebarItem(icon: "house.fill", title: "Home", isSelected: selectedView == .home) {
                    selectedView = .home
                }
                
                SidebarItem(icon: "magnifyingglass", title: "Search", isSelected: selectedView == .search) {
                    selectedView = .search
                }
                
                SidebarItem(icon: "music.note.list", title: "Library", isSelected: selectedView == .library) {
                    selectedView = .library
                }
            }
            .padding(.top, 8)
            
            Divider()
                .background(KurokulaTheme.gray)
                .padding(.top, 8)
            
            // Playlists
            VStack(alignment: .leading, spacing: 4) {
                Text("Playlists")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(KurokulaTheme.gray)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.playlists) { playlist in
                            Button(action: {}) {
                                Text(playlist.name)
                                    .font(.body)
                                    .foregroundColor(KurokulaTheme.foreground)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Connected Services
            VStack(alignment: .leading, spacing: 4) {
                Text("Connected")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(KurokulaTheme.gray)
                    .padding(.horizontal)
                
                ForEach(MusicProviderType.allCases) { provider in
                    HStack {
                        Image(systemName: provider.iconName)
                            .foregroundColor(KurokulaTheme.foreground)
                        Text(provider.displayName)
                            .font(.caption)
                            .foregroundColor(KurokulaTheme.foreground)
                        Spacer()
                        Circle()
                            .fill(isConnected(provider) ? KurokulaTheme.success : KurokulaTheme.gray)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            }
            .padding(.bottom, 8)
            
            Button(action: { selectedView = .settings }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .font(.body)
                .foregroundColor(KurokulaTheme.foreground)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
        .frame(width: 220)
        .background(KurokulaTheme.sidebar)
    }
    
    private func isConnected(_ provider: MusicProviderType) -> Bool {
        switch provider {
        case .youtubeMusic:
            return AuthManager.shared.isAuthenticatedYouTubeMusic
        case .soundcloud:
            return AuthManager.shared.isAuthenticatedSoundCloud
        case .local:
            return true
        }
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? KurokulaTheme.hoverBackground : Color.clear)
            )
            .foregroundColor(isSelected ? KurokulaTheme.secondary : KurokulaTheme.foreground)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

enum MainView {
    case home
    case search
    case library
    case settings
}
