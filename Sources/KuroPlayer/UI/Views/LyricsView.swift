import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Lyrics")
                    .font(.largeTitle.bold())
                Spacer()
                if viewModel.currentTrack != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewModel.currentTrack?.title ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(viewModel.currentTrack?.artist ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Content
            Group {
                if viewModel.isLoadingLyrics {
                    loadingState
                } else if let syncedLines = viewModel.syncedLyrics, !syncedLines.isEmpty {
                    SyncedLyricsContent(lines: syncedLines, currentTime: viewModel.currentTime)
                } else if let plain = viewModel.plainLyrics {
                    plainLyricsContent(plain)
                } else if viewModel.currentTrack != nil {
                    noLyricsState
                } else {
                    noTrackState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Fetching lyrics…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noLyricsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.quote")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No lyrics available")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Lyrics couldn't be found for this track")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTrackState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Play a song to see lyrics")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func plainLyricsContent(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
                .lineSpacing(8)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Synced Lyrics

struct SyncedLyricsContent: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    let lines: [LyricsService.LyricLine]
    let currentTime: TimeInterval

    private var activeIndex: Int {
        var idx = 0
        // Increased lead-in time to make the lyrics transition earlier
        let leadInTime = max(0, currentTime + 1.8)
        for (i, line) in lines.enumerated() {
            if leadInTime >= line.time {
                idx = i
            } else {
                break
            }
        }
        return idx
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    // Top spacer to center first lines
                    Color.clear.frame(height: 80)

                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let distance = abs(index - activeIndex)
                        Button(action: {
                            viewModel.seek(to: max(0, line.time - 1.8))
                        }) {
                            Text(line.text)
                                .font(.system(size: index == activeIndex ? 22 : 18,
                                              weight: index == activeIndex ? .bold : .medium))
                                .foregroundStyle(index == activeIndex ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
                                .opacity(distance <= 1 ? 1.0 : (distance == 2 ? 0.8 : (distance == 3 ? 0.5 : 0.25)))
                                .blur(radius: distance <= 1 ? 0 : (distance == 2 ? 1.2 : (distance == 3 ? 2.5 : 4.5)))
                                .scaleEffect(distance == 0 ? 1.02 : 1.0, anchor: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .animation(.easeOut(duration: 0.35), value: activeIndex)
                    }

                    // Bottom spacer
                    Color.clear.frame(height: 140)
                }
            }
            .scrollIndicators(.hidden)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: activeIndex) { _, newIndex in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
