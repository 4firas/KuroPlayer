import Foundation

protocol MusicProvider {
    var type: MusicProviderType { get }
    var isAuthenticated: Bool { get }
    
    func authenticate() async throws
    func logout() async throws
    func search(query: String) async throws -> [Track]
    func getTrack(id: String) async throws -> Track
    func getStreamURL(for track: Track) async throws -> URL
    func getLibrary() async throws -> [Track]
    func getPlaylists() async throws -> [Playlist]
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
