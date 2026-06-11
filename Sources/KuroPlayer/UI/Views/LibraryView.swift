import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(KurokulaTheme.foreground)
                
                Spacer()
                
                Button(action: {
                    Task { await viewModel.loadLibrary() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(KurokulaTheme.foreground)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.libraryTracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text("Your library is empty")
                        .font(.title2)
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text("Connect to YouTube Music or SoundCloud to see your saved tracks")
                        .font(.body)
                        .foregroundColor(KurokulaTheme.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.libraryTracks) { track in
                            Button(action: {
                                viewModel.setQueue(viewModel.libraryTracks)
                                viewModel.play(track: track)
                            }) {
                                TrackRowContent(track: track)
                            }
                            .buttonStyle(TrackRowButtonStyle(isActive: viewModel.currentTrack?.id == track.id))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(KurokulaTheme.background)
    }
}

// MARK: - Track Row Button Style

struct TrackRowButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(activeBackground(configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
    
    private func activeBackground(_ isPressed: Bool) -> Color {
        if isPressed {
            return KurokulaTheme.hoverBackground.opacity(0.6)
        }
        if isActive {
            return KurokulaTheme.hoverBackground
        }
        return Color.clear
    }
}

// MARK: - Track Row Content

struct TrackRowContent: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(KurokulaTheme.gray.opacity(0.3))
            }
            .frame(width: 44, height: 44)
            .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(KurokulaTheme.foreground)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(KurokulaTheme.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(track.providerType.displayName)
                .font(.caption2)
                .foregroundColor(KurokulaTheme.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(KurokulaTheme.gray.opacity(0.2))
                .cornerRadius(4)
            
            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(KurokulaTheme.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
