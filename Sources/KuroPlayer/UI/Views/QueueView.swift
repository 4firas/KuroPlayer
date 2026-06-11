import SwiftUI

struct QueueView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Play Queue")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(KurokulaTheme.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(KurokulaTheme.playerBar)

            List {
                ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, track in
                    HStack {
                        if index == viewModel.playbackEngine.state.currentIndex {
                            NowPlayingIndicator(isPlaying: viewModel.isPlaying)
                                .frame(width: 16)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(KurokulaTheme.gray)
                                .frame(width: 16)
                        }

                        VStack(alignment: .leading) {
                            Text(track.title)
                                .font(.body)
                                .foregroundColor(index == viewModel.playbackEngine.state.currentIndex ? KurokulaTheme.accent : KurokulaTheme.foreground)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(KurokulaTheme.gray)
                        }
                        Spacer()
                        Text(track.formattedDuration)
                            .font(.caption)
                            .foregroundColor(KurokulaTheme.gray)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.playQueue(at: index)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveQueue(from: source, to: destination)
                }
            }
            .listStyle(.plain)
        }
        .frame(width: 300, height: 400)
        .background(KurokulaTheme.background)
    }
}
