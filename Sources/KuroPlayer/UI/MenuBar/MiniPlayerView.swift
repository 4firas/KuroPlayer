import SwiftUI

// MARK: - Menu Bar Mini Player

struct MiniPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            if let track = viewModel.currentTrack {
                trackInfo(track: track)
                transportRow
            } else {
                emptyState
            }

            Divider()
                .background(.white.opacity(0.08))

            HStack {
                Button {
                    viewModel.selectedView = .settings
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open KuroPlayer", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.flat)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.flat)
                .tint(Theme.error)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func trackInfo(track: Track) -> some View {
        HStack(spacing: 10) {
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
            .frame(width: 36, height: 36)
            .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var transportRow: some View {
        HStack(spacing: 10) {
            Button { viewModel.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.isShuffled ? Theme.secondary : .secondary)
            }
            .buttonStyle(.flat)

            Button { viewModel.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.flat)

            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accent))
            }
            .buttonStyle(.plain)

            Button { viewModel.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.flat)

            Button { viewModel.cycleRepeatMode() } label: {
                Image(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.repeatMode != .off ? Theme.success : .secondary)
            }
            .buttonStyle(.flat)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            KuroBrandMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("Not Playing")
                    .font(.caption.weight(.medium))
                Text("Open KuroPlayer to choose a track")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
