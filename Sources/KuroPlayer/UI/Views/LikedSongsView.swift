import SwiftUI

struct LikedSongsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Liked Songs")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                
                Text("\(viewModel.likedTracks.count) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if viewModel.likedTracks.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No Liked Songs Yet")
                        .font(.title3.bold())
                    Text("Songs you like will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.likedTracks.enumerated()), id: \.element.id) { index, track in
                            Button(action: {
                                let remaining = Array(viewModel.likedTracks[index...])
                                viewModel.setQueue(remaining)
                                viewModel.play(track: track)
                            }) {
                                TrackRowContent(track: track)
                            }
                            .buttonStyle(.plain)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                            .contextMenu {
                                Button("Play Next") { viewModel.playNext(track) }
                                Button("Add to Queue") { viewModel.addToQueue(track) }
                                Divider()
                                Button(viewModel.isLiked(track) ? "Unlike" : "Like") {
                                    viewModel.toggleLike(track)
                                }
                                if !viewModel.playlists.isEmpty {
                                    Divider()
                                    Menu("Add to Playlist") {
                                        ForEach(viewModel.playlists) { playlist in
                                            Button(playlist.name) {
                                                viewModel.addToPlaylist(id: playlist.id, track: track)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
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
