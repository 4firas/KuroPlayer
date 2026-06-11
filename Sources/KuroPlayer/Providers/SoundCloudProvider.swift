import Foundation

class SoundCloudProvider: MusicProvider {
    var type: MusicProviderType { .soundcloud }
    var isAuthenticated: Bool { SoundCloudAuth.shared.accessToken != nil }
    
    private let baseURL = "https://api.soundcloud.com"
    
    func authenticate() async throws {
        try await SoundCloudAuth.shared.authenticate()
    }
    
    func logout() async throws {
        SoundCloudAuth.shared.logout()
    }
    
    func search(query: String) async throws -> [Track] {
        guard let token = SoundCloudAuth.shared.accessToken else {
            throw ProviderError.notAuthenticated
        }
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/tracks?q=\(encoded)&limit=20") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Search failed")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let items = json else {
            throw ProviderError.invalidResponse
        }
        
        return items.compactMap { parseTrack($0) }
    }
    
    func getTrack(id: String) async throws -> Track {
        guard let token = SoundCloudAuth.shared.accessToken else {
            throw ProviderError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)/tracks/\(id)") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.trackNotFound
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let trackDict = json,
              let track = parseTrack(trackDict) else {
            throw ProviderError.trackNotFound
        }
        
        return track
    }
    
    func getStreamURL(for track: Track) async throws -> URL {
        guard let token = SoundCloudAuth.shared.accessToken else {
            throw ProviderError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)/tracks/\(track.providerTrackId)/stream") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.streamUnavailable
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let streamURLString = json?["http_mp3_128_url"] as? String ?? json?["url"] as? String,
              let streamURL = URL(string: streamURLString) else {
            throw ProviderError.streamUnavailable
        }
        
        return streamURL
    }
    
    func getLibrary() async throws -> [Track] {
        guard let token = SoundCloudAuth.shared.accessToken else {
            throw ProviderError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)/me/favorites?limit=50") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Failed to fetch library")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let items = json else {
            throw ProviderError.invalidResponse
        }
        
        return items.compactMap { parseTrack($0) }
    }
    
    func getPlaylists() async throws -> [Playlist] {
        guard let token = SoundCloudAuth.shared.accessToken else {
            throw ProviderError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)/me/playlists?limit=50") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Failed to fetch playlists")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let items = json else {
            throw ProviderError.invalidResponse
        }
        
        return items.compactMap { parsePlaylist($0) }
    }
    
    private func parseTrack(_ dict: [String: Any]) -> Track? {
        guard let id = dict["id"] as? Int,
              let title = dict["title"] as? String,
              let durationMs = dict["duration"] as? Int else {
            return nil
        }
        
        var artist = "Unknown Artist"
        if let user = dict["user"] as? [String: Any],
           let username = user["username"] as? String {
            artist = username
        }
        
        var artworkURL: URL?
        if let artworkURLString = dict["artwork_url"] as? String {
            artworkURL = URL(string: artworkURLString)
        }
        
        var streamURL: URL?
        if let streamURLString = dict["stream_url"] as? String {
            streamURL = URL(string: streamURLString)
        }
        
        return Track(
            id: "soundcloud-\(id)",
            title: title,
            artist: artist,
            album: "",
            duration: Double(durationMs) / 1000.0,
            artworkURL: artworkURL,
            streamURL: streamURL,
            providerType: .soundcloud,
            providerTrackId: String(id)
        )
    }
    
    private func parsePlaylist(_ dict: [String: Any]) -> Playlist? {
        guard let id = dict["id"] as? Int,
              let title = dict["title"] as? String else {
            return nil
        }
        
        var tracks: [Track] = []
        if let trackDicts = dict["tracks"] as? [[String: Any]] {
            tracks = trackDicts.compactMap { parseTrack($0) }
        }
        
        return Playlist(
            id: "soundcloud-\(id)",
            name: title,
            tracks: tracks,
            providerType: .soundcloud,
            providerPlaylistId: String(id)
        )
    }
}
