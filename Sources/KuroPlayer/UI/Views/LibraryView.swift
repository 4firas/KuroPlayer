import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Namespace private var glassNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Your Library")
                    .font(.largeTitle.bold())

                Spacer()

                Button(action: {
                    Task { await viewModel.loadLibrary() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.flat)
            }
            .padding(24)

            if viewModel.libraryTracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Your library is empty")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("Add local music files or connect to streaming services")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(viewModel.libraryTracks.enumerated()), id: \.element.id) { index, track in
                            Button(action: {
                                // Set queue from this track onward
                                let remaining = Array(viewModel.libraryTracks[index...])
                                viewModel.setQueue(remaining)
                                viewModel.play(track: track)
                            }) {
                                TrackRowContent(track: track)
                            }
                            .buttonStyle(.plain)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                            .contextMenu {
                                TrackContextMenu(track: track, playlistId: nil, remainingQueue: Array(viewModel.libraryTracks[index...]))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

// MARK: - Track Row Content

struct TrackRowContent: View {
    let track: Track
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var store = UserDataStore.shared

    private var isActive: Bool {
        viewModel.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            ZStack {
                AsyncImage(url: track.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.quaternary)
                }
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 6))

                if isActive {
                    NowPlayingIndicator(isPlaying: viewModel.isPlaying)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Like indicator
            if viewModel.isLiked(track) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
            
            // Download indicator
            if store.downloadedTracks[track.id] != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.success)
            }

            // Provider badge
            Text(track.providerType.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.05)))

            // Duration
            Text(track.formattedDuration)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect(cornerRadius: 8))
    }
}


