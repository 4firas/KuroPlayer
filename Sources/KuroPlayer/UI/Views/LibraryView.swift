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
                .buttonStyle(.glass)
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
                    
                    Text("Connect to YouTube Music or SoundCloud to see your saved tracks")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 2) {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.libraryTracks) { track in
                                Button(action: {
                                    viewModel.setQueue(viewModel.libraryTracks)
                                    viewModel.play(track: track)
                                }) {
                                    TrackRowContent(track: track)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(
                                    .regular.interactive(),
                                    in: .rect(cornerRadius: 8)
                                )
                                .glassEffectID(track.id, in: glassNamespace)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
}

// MARK: - Track Row Content

struct TrackRowContent: View {
    let track: Track
    @EnvironmentObject var viewModel: PlayerViewModel
    
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
            
            // Provider badge
            Text(track.providerType.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular, in: .capsule)
            
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
