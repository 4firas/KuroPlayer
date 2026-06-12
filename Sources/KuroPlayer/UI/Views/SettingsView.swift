import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                Text("Settings")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 24)
                    .padding(.top, 24)



                // Equalizer
                EqualizerSettingsSection()
                    .padding(.horizontal, 24)
                    .zIndex(100)

                // Music Services
                VStack(alignment: .leading, spacing: 16) {
                    Text("Music Services")
                        .font(.title2.bold())

                    VStack(spacing: 12) {
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

                        Divider()

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
                    .glassCard(cornerRadius: 12)
                }
                .padding(.horizontal, 24)

                // Scrobbling
                VStack(alignment: .leading, spacing: 16) {
                    Text("Scrobbling")
                        .font(.title2.bold())

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
                    .padding()
                    .glassCard(cornerRadius: 12)
                }
                .padding(.horizontal, 24)

                // API Keys
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Keys")
                        .font(.title2.bold())

                    Text("Set your API keys here. Saved locally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Last.fm
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last.fm")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)

                        ApiKeyField(label: "API Key", key: "lastfm_api_key", placeholder: "Get from last.fm/api")
                        ApiKeyField(label: "Shared Secret", key: "lastfm_api_secret", placeholder: "Get from last.fm/api")
                    }
                    .padding()
                    .glassCard(cornerRadius: 12)

                    // SoundCloud
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SoundCloud")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)

                        ApiKeyField(label: "Client ID", key: "soundcloud_client_id", placeholder: "Not needed for anonymous scraping")
                        ApiKeyField(label: "Client Secret", key: "soundcloud_client_secret", placeholder: "Not needed for anonymous scraping")
                    }
                    .padding()
                    .glassCard(cornerRadius: 12)
                }
                .padding(.horizontal, 24)

                // About
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Version")
                                .foregroundStyle(.secondary)
                            Spacer()
                            // Seven clicks unlock the Kurokula theme switch.
                            Text("1.1.0")
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    theme.registerSecretTap()
                                }
                        }



                        if !YtDlp.isAvailable {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("yt-dlp not found — install with `brew install yt-dlp` to enable streaming")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
        .animation(.smooth(duration: 0.3), value: theme.justUnlocked)
        .animation(.smooth(duration: 0.3), value: theme.mode)
    }

}

struct ProviderRow: View {
    let name: String
    let icon: String
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)

            Text(name)
                .font(.body)

            Spacer()

            Circle()
                .fill(isConnected ? theme.success : .secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            if isConnected {
                Button("Disconnect", action: onDisconnect)
                    .buttonStyle(FlatButtonStyle())
                    .tint(theme.error)
            } else {
                Button("Connect", action: onConnect)
                    .buttonStyle(FlatButtonStyle())
                    .tint(Theme.accent)
            }
        }
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
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.caption)
        }
        .padding(8)
        .glassCard(cornerRadius: 6)
    }
}
