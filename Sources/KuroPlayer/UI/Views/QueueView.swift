import SwiftUI

struct QueueView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Play Queue")
                    .font(.title2.bold())
                
                Spacer()
                
                if !viewModel.queue.isEmpty {
                    Text("\(viewModel.queue.count) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            
            // Queue list
            if viewModel.queue.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Queue is empty")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Add tracks from your library or search")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, track in
                        QueueRow(
                            track: track,
                            index: index,
                            isActive: index == viewModel.playbackEngine.state.currentIndex
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .contentShape(.rect(cornerRadius: 8))
                        .onTapGesture {
                            viewModel.playQueue(at: index)
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveQueue(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 350, minHeight: 400)
        .backgroundExtensionEffect()
    }
}

struct QueueRow: View {
    let track: Track
    let index: Int
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Index or playing indicator
            ZStack {
                if isActive {
                    NowPlayingIndicator(isPlaying: true)
                        .frame(width: 20, height: 20)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? KurokulaTheme.accent : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.formattedDuration)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(isActive ? .regular.tint(KurokulaTheme.accent.opacity(0.2)) : .clear, in: .rect(cornerRadius: 8))
    }
}
