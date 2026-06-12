import SwiftUI

// MARK: - Playlist Card

class PlaylistCardState: ObservableObject {
    @Published var isHovered = false
}

struct PlaylistCard: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let fallbackSymbol: String
    let fallbackTint: Color
    let isExplicit: Bool
    let trackCount: Int?
    let isPlaying: Bool

    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var state = PlaylistCardState()
    @Namespace private var cardNamespace

    init(
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        fallbackSymbol: String = "music.note.list",
        fallbackTint: Color = Theme.accent,
        isExplicit: Bool = false,
        trackCount: Int? = nil,
        isPlaying: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.fallbackSymbol = fallbackSymbol
        self.fallbackTint = fallbackTint
        self.isExplicit = isExplicit
        self.trackCount = trackCount
        self.isPlaying = isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
            titleRow
        }
        .contentShape(.rect)
        .scaleEffect(state.isHovered ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.2), value: state.isHovered)
        .onHover { hovering in
            state.isHovered = hovering
        }
    }

    // MARK: Artwork

    private var artwork: some View {
        ZStack {
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if isExplicit {
                ExplicitBadge()
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isPlaying {
                NowPlayingIndicator(isPlaying: true)
                    .frame(width: 48, height: 48)
                    .padding(8)
                    .background(.black.opacity(0.55))
                    .clipShape(.circle)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay {
            if state.isHovered {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.25))
                    Image(systemName: "play.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6)
                        .offset(x: 2)
                }
                .transition(.opacity)
            }
        }
        // removed glassEffectID
        .animation(.smooth(duration: 0.2), value: isPlaying)
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [
                    fallbackTint.opacity(0.85),
                    fallbackTint.opacity(0.45),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: fallbackSymbol)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
    }

    // MARK: Title Row

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isExplicit {
                ExplicitBadge()
                    .scaleEffect(0.85)
            }
        }
    }
}

// MARK: - Explicit Badge

struct ExplicitBadge: View {
    var body: some View {
        Text("E")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: 14, height: 14)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.secondary, lineWidth: 1)
            )
    }
}
