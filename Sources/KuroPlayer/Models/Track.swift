import Foundation

enum MusicProviderType: String, Codable, CaseIterable, Identifiable {
    case youtubeMusic
    case soundcloud
    case local
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youtubeMusic: return "YouTube Music"
        case .soundcloud: return "SoundCloud"
        case .local: return "Local Files"
        }
    }

    var iconName: String {
        switch self {
        case .youtubeMusic: return "play.rectangle"
        case .soundcloud: return "cloud"
        case .local: return "folder"
        }
    }
}

struct Track: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkURL: URL?
    let streamURL: URL?
    let providerType: MusicProviderType
    let providerTrackId: String
    var isLiked: Bool = false

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
