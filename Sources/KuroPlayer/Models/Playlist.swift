import Foundation

struct Playlist: Identifiable, Codable {
    let id: String
    var name: String
    var tracks: [Track]
    let providerType: MusicProviderType?
    let providerPlaylistId: String?
    var createdAt: Date

    /// Playlist-level artwork (e.g. a SoundCloud set cover or a YouTube
    /// playlist thumbnail) — not the first track's artwork.
    var artworkURL: URL?
    /// Channel/user that owns the playlist on the source service.
    var uploader: String?
    /// Original URL the playlist was imported from; used to re-sync.
    var sourceURL: URL?

    init(id: String = UUID().uuidString, name: String, tracks: [Track] = [],
         providerType: MusicProviderType? = nil, providerPlaylistId: String? = nil,
         artworkURL: URL? = nil, uploader: String? = nil, sourceURL: URL? = nil) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.providerType = providerType
        self.providerPlaylistId = providerPlaylistId
        self.createdAt = Date()
        self.artworkURL = artworkURL
        self.uploader = uploader
        self.sourceURL = sourceURL
    }

    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }

    var formattedTotalDuration: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }

    /// Best displayable artwork: playlist cover first, first track as fallback.
    var displayArtworkURL: URL? {
        artworkURL ?? tracks.first?.artworkURL
    }
}
