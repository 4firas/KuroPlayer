import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var store = UserDataStore.shared

    var playlist: Playlist? {
        guard let id = viewModel.selectedPlaylistId else { return nil }
        return viewModel.playlists.first(where: { $0.id == id })
    }

    var body: some View {
        if let playlist = playlist {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 24) {
                        // Artwork
                        Group {
                            if let artwork = playlist.artworkURL {
                                AsyncImage(url: artwork) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        PlaylistThumbnail(symbol: "music.note.list", tint: Theme.accent, size: 80)
                                    }
                                }
                            } else if let trackArt = playlist.tracks.first?.artworkURL {
                                AsyncImage(url: trackArt) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        PlaylistThumbnail(symbol: "music.note.list", tint: Theme.accent, size: 80)
                                    }
                                }
                            } else {
                                PlaylistThumbnail(symbol: "music.note.list", tint: Theme.accent, size: 80)
                            }
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("PLAYLIST")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.accent)

                            Text(playlist.name)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            HStack {
                                Text("\(playlist.trackCount) songs • \(formatDuration(playlist.totalDuration))")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                
                                let state = playlistDownloadState(for: playlist)
                                if !state.text.isEmpty {
                                    Text("• \(state.text)")
                                        .font(.title3.bold())
                                        .foregroundStyle(state.color)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    if let first = playlist.tracks.first {
                                        viewModel.play(track: first)
                                    }
                                }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(Theme.accent))
                                }
                                .buttonStyle(.plain)
                                .disabled(playlist.tracks.isEmpty)
                                
                                Button(action: {
                                    viewModel.downloadPlaylist(playlist)
                                }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Theme.accent, .primary.opacity(0.1))
                                }
                                .buttonStyle(.plain)
                                .help("Download Playlist")
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                    // Tracks List
                    LazyVStack(spacing: 8) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            Button(action: {
                                let remaining = Array(playlist.tracks[index...])
                                viewModel.setQueue(remaining)
                                viewModel.play(track: track)
                            }) {
                                TrackRowContent(track: track)
                            }
                            .buttonStyle(.plain)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                            .contextMenu {
                                TrackContextMenu(track: track, playlistId: playlist.id, remainingQueue: Array(playlist.tracks[index...]))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
        } else {
            Text("Playlist not found")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    private func playlistDownloadState(for playlist: Playlist) -> (text: String, color: Color) {
        guard !playlist.tracks.isEmpty else { return ("", .clear) }
        let downloadedCount = playlist.tracks.filter { store.downloadedTracks[$0.id] != nil }.count
        if downloadedCount == 0 { return ("", .clear) }
        if downloadedCount == playlist.tracks.count { return ("Downloaded", Theme.success) }
        return ("Partially Downloaded (\(downloadedCount)/\(playlist.tracks.count))", Theme.secondary)
    }
}


