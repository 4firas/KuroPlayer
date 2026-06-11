import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            if let track = viewModel.currentTrack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(KurokulaTheme.accent)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                    .glassEffect(.regular, in: .capsule)
                }
                .frame(height: 4)
                .onTapGesture { location in
                    // TODO: Add scrubbing
                }
            }
            
            // Controls
            HStack(spacing: 20) {
                // Track info
                if let track = viewModel.currentTrack {
                    HStack(spacing: 12) {
                        AsyncImage(url: track.artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 48, height: 48)
                                .background(.quaternary)
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(.rect(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 250, alignment: .leading)
                } else {
                    Text("No track playing")
                        .foregroundColor(.secondary)
                        .frame(width: 250, alignment: .leading)
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 16) {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.currentTrack == nil)
                    
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.currentTrack == nil)
                    
                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.currentTrack == nil)
                }
                
                Spacer()
                
                // Volume and time
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.sliderVolume, in: 0...1)
                        .onChange(of: viewModel.sliderVolume) { _, newValue in
                            viewModel.setVolume(Float(newValue))
                        }
                        .frame(width: 100)
                    
                    if let track = viewModel.currentTrack {
                        Text(formatTime(viewModel.currentTime))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        
                        Text("/")
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(track.duration))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 250, alignment: .trailing)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    private var progress: Double {
        guard let track = viewModel.currentTrack, track.duration > 0 else { return 0 }
        return viewModel.currentTime / track.duration
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
