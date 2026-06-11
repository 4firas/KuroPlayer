import Foundation

struct Playlist: Identifiable, Codable {
    let id: String
    var name: String
    var tracks: [Track]
    let providerType: MusicProviderType?
    let providerPlaylistId: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, tracks: [Track] = [], 
         providerType: MusicProviderType? = nil, providerPlaylistId: String? = nil) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.providerType = providerType
        self.providerPlaylistId = providerPlaylistId
        self.createdAt = Date()
    }

    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
}
