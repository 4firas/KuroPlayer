import Foundation

/// Persists user data (liked tracks, custom playlists) to disk.
/// Stored at ~/Library/Application Support/KuroPlayer/user_data.json
@MainActor
class UserDataStore: ObservableObject {
    static let shared = UserDataStore()

    @Published private(set) var likedTrackIds: Set<String> = []
    @Published private(set) var likedTracks: [Track] = []
    @Published private(set) var userPlaylists: [Playlist] = []

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KuroPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("user_data.json")
        load()
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

    // MARK: - Playlists

    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(name: name)
        userPlaylists.append(playlist)
        save()
        return playlist
    }

    func deletePlaylist(id: String) {
        userPlaylists.removeAll { $0.id == id }
        save()
    }

    func renamePlaylist(id: String, name: String) {
        guard let index = userPlaylists.firstIndex(where: { $0.id == id }) else { return }
        userPlaylists[index].name = name
        save()
    }

    func addToPlaylist(id: String, track: Track) {
        guard let index = userPlaylists.firstIndex(where: { $0.id == id }) else { return }
        guard !userPlaylists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        userPlaylists[index].tracks.append(track)
        save()
    }

    func removeFromPlaylist(id: String, trackId: String) {
        guard let index = userPlaylists.firstIndex(where: { $0.id == id }) else { return }
        userPlaylists[index].tracks.removeAll { $0.id == trackId }
        save()
    }

    func addImportedPlaylist(_ playlist: Playlist) {
        userPlaylists.append(playlist)
        save()
    }

    // MARK: - Persistence

    private struct StoredData: Codable {
        var likedTracks: [Track]
        var userPlaylists: [Playlist]
    }

    private func save() {
        let data = StoredData(likedTracks: likedTracks, userPlaylists: userPlaylists)
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
            userPlaylists = stored.userPlaylists
        } catch {
            print("UserDataStore load error: \(error)")
        }
    }
}
