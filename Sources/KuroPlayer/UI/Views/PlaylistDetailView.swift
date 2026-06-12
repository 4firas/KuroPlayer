import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: String

    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var playlistStore = PlaylistStore.shared
    @EnvironmentObject private var theme: ThemeManager

    private var playlist: Playlist? {
        playlistStore.playlist(id: playlistID)
    }

    var body: some View {
        if let playlist {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(for: playlist)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    // Track list
                    GlassEffectContainer(spacing: 2) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                                Button(action: {
                                    viewModel.playFromList(playlist.tracks, startingAt: index)
                                }) {
                                    HStack(spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 28, alignment: .trailing)

                                        TrackRowContent(track: track)
                                    }
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                                .contextMenu {
                                    Button("Add to Queue") {
                                        viewModel.addToQueue(track)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Playlist not found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Back to Playlists") {
                    viewModel.selectedView = .playlists
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(for playlist: Playlist) -> some View {
        HStack(alignment: .bottom, spacing: 20) {
            PlaylistArtwork(url: playlist.displayArtworkURL, cornerRadius: 16)
                .frame(width: 180, height: 180)
                .shadow(radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                if let providerType = playlist.providerType {
                    Label(providerType.displayName, systemImage: providerType.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassEffect(.regular, in: .capsule)
                }

                Text(playlist.name)
                    .font(.largeTitle.bold())
                    .lineLimit(2)

                if let uploader = playlist.uploader, !uploader.isEmpty {
                    Text("by \(uploader)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("\(playlist.trackCount) tracks • \(playlist.formattedTotalDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.playFromList(playlist.tracks, startingAt: 0)
                    }) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(playlist.tracks.isEmpty)

                    Button(action: {
                        viewModel.playShuffled(playlist.tracks)
                    }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.glass)
                    .disabled(playlist.tracks.isEmpty)

                    if playlist.sourceURL != nil {
                        Button(action: {
                            viewModel.refreshPlaylist(playlist)
                        }) {
                            if viewModel.isImportingPlaylist {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.isImportingPlaylist)
                        .help("Re-sync from source")
                    }

                    Button(role: .destructive, action: {
                        viewModel.removePlaylist(playlist)
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.glass)
                    .tint(theme.error)
                    .help("Remove playlist")
                }
                .padding(.top, 4)
            }

            Spacer()
        }
    }
}
