import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        VStack {
            if let track = viewModel.currentTrack {
                Text(track.title).font(.headline).lineLimit(1)
                Text(track.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1)

                HStack(spacing: 20) {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            } else {
                Text("Not Playing").foregroundColor(.secondary)
            }

            Divider().padding(.vertical, 8)

            Button("Quit KuroPlayer") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 250)
    }
}
