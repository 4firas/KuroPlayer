import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var playlistStore = PlaylistStore.shared
    @EnvironmentObject private var theme: ThemeManager

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Playlists")
                .font(.largeTitle.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)

            // Import bar
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)

                TextField("Paste a SoundCloud set or YouTube playlist link...", text: $viewModel.playlistImportText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.importPlaylist(from: viewModel.playlistImportText)
                    }

                if viewModel.isImportingPlaylist {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Import") {
                        viewModel.importPlaylist(from: viewModel.playlistImportText)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.playlistImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 16)

            if let status = viewModel.importStatusMessage {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            // Grid
            if playlistStore.playlists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No playlists yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Import a SoundCloud set or a YouTube / YouTube Music playlist by pasting its link above")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(playlistStore.playlists) { playlist in
                            PlaylistCard(playlist: playlist)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct PlaylistCard: View {
    let playlist: Playlist

    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Button(action: {
            viewModel.selectedView = .playlist(playlist.id)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                PlaylistArtwork(url: playlist.displayArtworkURL, cornerRadius: 12)
                    .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let providerType = playlist.providerType {
                            Image(systemName: providerType.iconName)
                                .font(.caption2)
                        }
                        Text("\(playlist.trackCount) tracks • \(playlist.formattedTotalDuration)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .contextMenu {
            Button("Play") {
                viewModel.playFromList(playlist.tracks, startingAt: 0)
            }
            Button("Shuffle") {
                viewModel.playShuffled(playlist.tracks)
            }
            Divider()
            Button("Remove Playlist", role: .destructive) {
                viewModel.removePlaylist(playlist)
            }
        }
    }
}

/// Square playlist artwork with a consistent placeholder.
struct PlaylistArtwork: View {
    let url: URL?
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
