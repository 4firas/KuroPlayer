import Foundation

@MainActor protocol MusicProvider: Sendable {
    var type: MusicProviderType { get }
    var isAuthenticated: Bool { get }
    
    func authenticate() async throws
    func logout() async throws
    func search(query: String) async throws -> [Track]
    func getTrack(id: String) async throws -> Track
    func getStreamURL(for track: Track) async throws -> URL
    func getLibrary() async throws -> [Track]
    func getPlaylists() async throws -> [Playlist]

    func createPlaylist(name: String) async throws -> Playlist
    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws
    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws
    func deletePlaylist(playlist: Playlist) async throws
}

enum ProviderError: Error, LocalizedError {
    case notAuthenticated
    case networkError(String)
    case invalidResponse
    case trackNotFound
    case streamUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with provider"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from provider"
        case .trackNotFound:
            return "Track not found"
        case .streamUnavailable:
            return "Stream unavailable"
        }
    }
}
