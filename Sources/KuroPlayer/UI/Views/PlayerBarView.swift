import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            if viewModel.currentTrack != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(KurokulaTheme.gray.opacity(0.3))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(KurokulaTheme.accent)
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percent = min(max(value.location.x / geometry.size.width, 0), 1)
                                let time = viewModel.duration * Double(percent)
                                viewModel.seek(to: time)
                            }
                    )
                }
                .frame(height: 3)
            }
            
            HStack(spacing: 16) {
                // Track info
                HStack(spacing: 12) {
                    if let track = viewModel.currentTrack {
                        AsyncImage(url: track.artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(KurokulaTheme.gray.opacity(0.3))
                        }
                        .frame(width: 56, height: 56)
                        .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(KurokulaTheme.foreground)
                                .lineLimit(1)
                            
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(KurokulaTheme.gray)
                                .lineLimit(1)
                        }
                    } else {
                        Text("No track playing")
                            .font(.body)
                            .foregroundColor(KurokulaTheme.gray)
                    }
                }
                .frame(width: 250, alignment: .leading)
                
                Spacer()
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: viewModel.previous) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(KurokulaTheme.foreground)
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(0.8)
                    
                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(KurokulaTheme.secondary)
                    }
                    .buttonStyle(.borderless)
                    .overlay(
                        Circle()
                            .stroke(KurokulaTheme.secondary.opacity(0.3), lineWidth: 1)
                            .scaleEffect(1.4)
                    )
                    
                    Button(action: viewModel.next) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(KurokulaTheme.foreground)
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                // Time and volume
                HStack(spacing: 12) {
                    Text(formatTime(viewModel.currentTime))
                        .font(.caption)
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text("/")
                        .font(.caption)
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text(formatTime(viewModel.duration))
                        .font(.caption)
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Image(systemName: "speaker.fill")
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Slider(value: $viewModel.sliderVolume, in: 0...1)
                        .onChange(of: viewModel.sliderVolume) { newVal in
                            viewModel.setVolume(Float(newVal))
                        }
                        .frame(width: 100)
                }
                .frame(width: 250, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(KurokulaTheme.playerBar)
        .onAppear {
            viewModel.sliderVolume = Double(viewModel.volume)
        }
    }
    
    private var progress: Double {
        guard viewModel.duration > 0 else { return 0 }
        return viewModel.currentTime / viewModel.duration
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
