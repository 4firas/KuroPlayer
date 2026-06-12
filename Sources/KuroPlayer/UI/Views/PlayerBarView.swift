import SwiftUI

// MARK: - Player Bar
//
// Single-row layout:
//   —————————————————————  ← progress
//  [🎵 Title — Artist] [⏮ ▶ ⏭] [🔊]

class PlayerBarState: ObservableObject {
    @Published var scrubbingProgress: Double? = nil
}

struct PlayerBarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var state = PlayerBarState()
    @Namespace private var playNamespace

    private var displayProgress: Double {
        if let scrubbingProgress = state.scrubbingProgress { return scrubbingProgress }
        guard let track = viewModel.currentTrack, track.duration > 0 else { return 0 }
        return viewModel.currentTime / track.duration
    }

    var body: some View {
        VStack(spacing: 4) {
            // Progress / scrubber
            if viewModel.currentTrack != nil {
                progressBar
            }

            // Single row: artwork + transport + right controls
            HStack(spacing: 0) {
                leftSection
                    .frame(maxWidth: .infinity, alignment: .leading)

                transportSection

                rightSection
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.35), radius: 12, y: -2)
        )
    }

    // MARK: Progress

    private var progressBar: some View {
        let progressBinding = Binding<Double>(
            get: { state.scrubbingProgress ?? displayProgress },
            set: { state.scrubbingProgress = $0 }
        )

        return Slider(value: progressBinding, in: 0...1) { isEditing in
            if !isEditing {
                if let track = viewModel.currentTrack, let p = state.scrubbingProgress {
                    viewModel.seek(to: p * track.duration)
                }
                state.scrubbingProgress = nil
            } else if state.scrubbingProgress == nil {
                state.scrubbingProgress = displayProgress
            }
        }
        .tint(Theme.accent)
        .background(ScrollWheelHandler { dx, dy in
            guard let track = viewModel.currentTrack else { return }
            let delta = (abs(dx) > abs(dy) ? dx : -dy) * 0.2
            let newTime = max(0, min(track.duration, viewModel.currentTime + delta))
            viewModel.seek(to: newTime)
        })
        .frame(height: 14)
    }

    // MARK: Left — artwork + track info + heart

    private var leftSection: some View {
        HStack(spacing: 10) {
            if viewModel.isLoadingTrack {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 32, height: 32)
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let track = viewModel.currentTrack {
                artworkThumb(track: track)
                trackText(track: track)

                // Heart / like button
                Button {
                    viewModel.toggleLike(track)
                } label: {
                    Image(systemName: viewModel.isLiked(track) ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.isLiked(track) ? Theme.accent : .secondary)
                }
                .buttonStyle(.plain)
                .animation(.smooth(duration: 0.2), value: viewModel.isLiked(track))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("No track playing")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 2)
    }

    private func artworkThumb(track: Track) -> some View {
        AsyncImage(url: track.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    Color.gray.opacity(0.25)
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(.rect(cornerRadius: 6))
    }

    private func trackText(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(track.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(track.artist)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: 180, alignment: .leading)
    }

    // MARK: Center — transport controls

    private var transportSection: some View {
        HStack(spacing: 4) {
            TransportButton(systemName: "shuffle", isActive: viewModel.isShuffled,
                            activeTint: Theme.accent) { viewModel.toggleShuffle() }

            TransportButton(systemName: "backward.fill") { viewModel.previous() }
                .disabled(viewModel.currentTrack == nil)

            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    if viewModel.isPlaying {
                        Image(systemName: "pause.fill")
                            .matchedGeometryEffect(id: "playState", in: playNamespace)
                    } else {
                        Image(systemName: "play.fill")
                            .matchedGeometryEffect(id: "playState", in: playNamespace)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.4), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentTrack == nil)
            .animation(.smooth(duration: 0.18), value: viewModel.isPlaying)

            TransportButton(systemName: "forward.fill") { viewModel.next() }
                .disabled(viewModel.currentTrack == nil)

            TransportButton(
                systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat",
                isActive: viewModel.repeatMode != .off,
                activeTint: Theme.accent
            ) { viewModel.cycleRepeatMode() }
        }
    }

    // MARK: Right — lyrics / queue / volume

    private var rightSection: some View {
        HStack(spacing: 4) {
            TransportButton(systemName: "text.quote",
                            isActive: viewModel.selectedView == .lyrics,
                            activeTint: Theme.accent) {
                viewModel.selectedView = viewModel.selectedView == .lyrics ? .home : .lyrics
            }
            TransportButton(systemName: "list.bullet") { viewModel.selectedView = .queue }
            VolumeControl()
        }
    }
}

class TransportButtonState: ObservableObject {
    @Published var isHovered = false
}

struct TransportButton: View {
    let systemName: String
    var isActive: Bool = false
    var activeTint: Color = .primary
    var action: () -> Void

    @StateObject private var state = TransportButtonState()

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background {
                    if isActive {
                        Circle()
                            .fill(activeTint.opacity(0.18))
                            .frame(width: 26, height: 26)
                    } else if state.isHovered {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 26, height: 26)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { state.isHovered = $0 }
    }

    private var iconColor: Color {
        if isActive { return activeTint }
        return state.isHovered ? .white : Color.white.opacity(0.78)
    }
}

class VolumeControlState: ObservableObject {
    @Published var isHovered = false
}

struct VolumeControl: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var state = VolumeControlState()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: volumeIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Slider(value: $viewModel.sliderVolume, in: 0...1) { _ in
                viewModel.setVolume(Float(viewModel.sliderVolume))
            }
            .tint(Theme.accent)
            .frame(width: state.isHovered ? 90 : 0)
            .opacity(state.isHovered ? 1 : 0)
            .animation(.smooth(duration: 0.2), value: state.isHovered)
        }
        .padding(.horizontal, 4)
        .frame(height: 28)
        .contentShape(.rect)
        .background(ScrollWheelHandler { _, dy in
            // User requested: down makes it lower, up makes it higher.
            // In macOS, swiping up (natural) gives dy > 0.
            let delta = Double(dy) * 0.01
            let newVol = max(0, min(1, viewModel.sliderVolume + Float(delta)))
            viewModel.sliderVolume = newVol
            viewModel.setVolume(newVol)
        })
        .onHover { state.isHovered = $0 }
    }

    private var volumeIcon: String {
        let v = viewModel.sliderVolume
        if v == 0 { return "speaker.slash.fill" }
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat, CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ScrollCatcherView {
            view.onScroll = onScroll
        }
    }
}

class ScrollCatcherView: NSView {
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
    }
}
