import Foundation

/// Local persistence for imported playlists. Saved as JSON in Application
/// Support so playlists survive restarts.
@MainActor
final class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()

    @Published private(set) var playlists: [Playlist] = []

    private let fileURL: URL

    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KuroPlayer")
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        fileURL = appDir.appendingPathComponent("playlists.json")
        load()
    }

    func playlist(id: String) -> Playlist? {
        playlists.first { $0.id == id }
    }

    /// Adds a playlist, replacing any earlier import of the same source.
    func upsert(_ playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
        } else {
            playlists.append(playlist)
        }
        save()
    }

    func remove(id: String) {
        playlists.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return
        }
        playlists = saved
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
}
