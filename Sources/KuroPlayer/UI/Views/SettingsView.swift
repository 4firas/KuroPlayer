import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(KurokulaTheme.foreground)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Music Services
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Music Services")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        ProviderRow(
                            name: "YouTube Music",
                            icon: "play.rectangle",
                            isConnected: AuthManager.shared.isAuthenticatedYouTubeMusic,
                            onConnect: {
                                Task { await viewModel.authenticateProvider(.youtubeMusic) }
                            },
                            onDisconnect: {
                                Task { await viewModel.logoutProvider(.youtubeMusic) }
                            }
                        )
                        
                        ProviderRow(
                            name: "SoundCloud",
                            icon: "cloud",
                            isConnected: AuthManager.shared.isAuthenticatedSoundCloud,
                            onConnect: {
                                Task { await viewModel.authenticateProvider(.soundcloud) }
                            },
                            onDisconnect: {
                                Task { await viewModel.logoutProvider(.soundcloud) }
                            }
                        )
                    }
                    .padding()
                    .background(KurokulaTheme.cardBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Scrobbling
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scrobbling")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        ProviderRow(
                            name: "Last.fm",
                            icon: "waveform",
                            isConnected: AuthManager.shared.isAuthenticatedLastFm,
                            onConnect: {
                                Task {
                                    do {
                                        try await LastFmAuth.shared.authenticate()
                                        AuthManager.shared.refreshState()
                                    } catch {
                                        viewModel.errorMessage = error.localizedDescription
                                    }
                                }
                            },
                            onDisconnect: {
                                LastFmAuth.shared.logout()
                                AuthManager.shared.refreshState()
                            }
                        )
                    }
                    .padding()
                    .background(KurokulaTheme.cardBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // API Keys
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Keys")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        Text("Set your API keys here. Saved locally.")
                            .font(.caption)
                            .foregroundColor(KurokulaTheme.gray)
                        
                        Group {
                            Text("Last.fm")
                                .font(.headline)
                                .foregroundColor(KurokulaTheme.secondary)
                            
                            ApiKeyField(label: "API Key", key: "lastfm_api_key", placeholder: "Get from last.fm/api")
                            ApiKeyField(label: "Shared Secret", key: "lastfm_api_secret", placeholder: "Get from last.fm/api")
                        }
                        
                        Group {
                            Text("SoundCloud")
                                .font(.headline)
                                .foregroundColor(KurokulaTheme.secondary)
                            
                            ApiKeyField(label: "Client ID", key: "soundcloud_client_id", placeholder: "Get from soundcloud.com/developers")
                            ApiKeyField(label: "Client Secret", key: "soundcloud_client_secret", placeholder: "Get from soundcloud.com/developers")
                        }
                    }
                    .padding()
                    .background(KurokulaTheme.cardBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(KurokulaTheme.foreground)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Version")
                                    .foregroundColor(KurokulaTheme.gray)
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(KurokulaTheme.foreground)
                            }
                            
                            HStack {
                                Text("Theme")
                                    .foregroundColor(KurokulaTheme.gray)
                                Spacer()
                                Text("Kurokula")
                                    .foregroundColor(KurokulaTheme.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(KurokulaTheme.cardBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .background(KurokulaTheme.background)
    }
}

struct ProviderRow: View {
    let name: String
    let icon: String
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(KurokulaTheme.foreground)
                .frame(width: 24)
            
            Text(name)
                .font(.body)
                .foregroundColor(KurokulaTheme.foreground)
            
            Spacer()
            
            if isConnected {
                Circle()
                    .fill(KurokulaTheme.success)
                    .frame(width: 8, height: 8)
                
                Button("Disconnect", action: onDisconnect)
                    .buttonStyle(.borderless)
                    .foregroundColor(KurokulaTheme.error)
            } else {
                Circle()
                    .fill(KurokulaTheme.gray)
                    .frame(width: 8, height: 8)
                
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderless)
                    .foregroundColor(KurokulaTheme.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - API Key Field

struct ApiKeyField: View {
    let label: String
    let key: String
    let placeholder: String
    
    private var text: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: key) ?? "" },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )
    }
    
    init(label: String, key: String, placeholder: String) {
        self.label = label
        self.key = key
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(KurokulaTheme.gray)
                .frame(width: 100, alignment: .leading)
            
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundColor(KurokulaTheme.foreground)
                .padding(6)
                .background(KurokulaTheme.background)
                .cornerRadius(4)
        }
    }
}
