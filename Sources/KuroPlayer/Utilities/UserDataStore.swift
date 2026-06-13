import Foundation

/// Persists user data (liked tracks, custom playlists) to disk.
/// Stored at ~/Library/Application Support/KuroPlayer/user_data.json
@MainActor
class UserDataStore: ObservableObject {
    static let shared = UserDataStore()

    @Published private(set) var likedTrackIds: Set<String> = []
    @Published private(set) var likedTracks: [Track] = []
    @Published private(set) var userPlaylists: [Playlist] = []
    @Published private(set) var downloadedTracks: [String: String] = [:]

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KuroPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("user_data.json")
        load()
    }

    func addDownloadedTrack(id: String, path: String) {
        downloadedTracks[id] = path
        save()
    }

    func removeDownloadedTrack(id: String) {
        downloadedTracks.removeValue(forKey: id)
        save()
    }

    // MARK: - Likes

    func isLiked(_ track: Track) -> Bool {
        likedTrackIds.contains(track.id)
    }

    func toggleLike(_ track: Track) {
        if likedTrackIds.contains(track.id) {
            likedTrackIds.remove(track.id)
            likedTracks.removeAll { $0.id == track.id }
        } else {
            likedTrackIds.insert(track.id)
            likedTracks.append(track)
        }
        save()
    }

    // MARK: - Persistence

    private struct StoredData: Codable {
        var likedTracks: [Track]
        var userPlaylists: [Playlist]?
        var downloadedTracks: [String: String]?
    }

    private func save() {
        let data = StoredData(
            likedTracks: likedTracks,
            userPlaylists: userPlaylists,
            downloadedTracks: downloadedTracks
        )
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("UserDataStore save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try JSONDecoder().decode(StoredData.self, from: data)
            likedTracks = stored.likedTracks
            likedTrackIds = Set(stored.likedTracks.map(\.id))
            userPlaylists = stored.userPlaylists ?? []
            downloadedTracks = stored.downloadedTracks ?? [:]
        } catch {
            print("UserDataStore load error: \(error)")
        }
    }
}
