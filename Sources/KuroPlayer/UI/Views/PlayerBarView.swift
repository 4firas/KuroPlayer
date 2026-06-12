import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 10) {
            // Scrubbable progress row: elapsed — bar — total
            if viewModel.currentTrack != nil {
                HStack(spacing: 10) {
                    Text(formatTime(displayedTime))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)

                    KuroSlider(value: progressBinding) {
                        commitScrub()
                    }
                    .disabled(viewModel.isLoadingTrack)
                    .opacity(viewModel.isLoadingTrack ? 0.5 : 1)

                    Text(formatTime(viewModel.duration))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
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
                HStack(spacing: 14) {
                    Button(action: { viewModel.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.body)
                            .foregroundStyle(viewModel.isShuffled ? theme.accent : .secondary)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.queue.isEmpty)
                    .help("Shuffle")

                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.currentTrack == nil)

                    Button(action: { viewModel.togglePlayPause() }) {
                        ZStack {
                            if viewModel.isLoadingTrack {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                            }
                        }
                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.currentTrack == nil || viewModel.isLoadingTrack)

                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.currentTrack == nil)

                    Button(action: { viewModel.cycleRepeatMode() }) {
                        Image(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.body)
                            .foregroundStyle(viewModel.repeatMode == .off ? .secondary : theme.accent)
                    }
                    .buttonStyle(.glass)
                    .help("Repeat")
                }

                Spacer()

                // Volume
                HStack(spacing: 10) {
                    Image(systemName: volumeIcon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    KuroSlider(value: volumeBinding)
                        .frame(width: 110)
                }
                .frame(width: 250, alignment: .trailing)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    // MARK: - Scrubbing

    /// While dragging, the bar follows the finger via scrubFraction; release
    /// commits the seek.
    private var progressBinding: Binding<Double> {
        Binding(
            get: { viewModel.scrubFraction ?? progress },
            set: { viewModel.scrubFraction = $0 }
        )
    }

    private func commitScrub() {
        guard let fraction = viewModel.scrubFraction else { return }
        viewModel.seek(to: fraction * viewModel.duration)
        viewModel.scrubFraction = nil
    }

    private var displayedTime: TimeInterval {
        if let fraction = viewModel.scrubFraction {
            return fraction * viewModel.duration
        }
        return viewModel.currentTime
    }

    private var progress: Double {
        guard viewModel.duration > 0 else { return 0 }
        return (viewModel.currentTime / viewModel.duration).clamped(to: 0...1)
    }

    // MARK: - Volume

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.volume) },
            set: { viewModel.setVolume(Float($0)) }
        )
    }

    private var volumeIcon: String {
        switch viewModel.volume {
        case 0: return "speaker.slash.fill"
        case ..<0.33: return "speaker.wave.1.fill"
        case ..<0.66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
