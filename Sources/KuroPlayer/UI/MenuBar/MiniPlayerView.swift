import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if let track = viewModel.currentTrack {
                // Track info
                HStack(spacing: 8) {
                    AsyncImage(url: track.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(.rect(cornerRadius: 4))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Controls
                HStack(spacing: 16) {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.glass)
                    
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body)
                    }
                    .buttonStyle(.glassProminent)
                    
                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Text("Not Playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Button("Quit KuroPlayer") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.glass)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 240)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
