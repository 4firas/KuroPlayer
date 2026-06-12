import Foundation
import AVFoundation

@MainActor class LocalFileProvider: MusicProvider {
    var type: MusicProviderType { .local }
    var isAuthenticated: Bool { true }

    private let fileManager = FileManager.default
    private let supportedExtensions = ["mp3", "m4a", "flac", "wav"]

    /// Scanning the Music folder reads metadata for every file — far too slow
    /// to repeat per search, so the result is cached briefly.
    private var cachedLibrary: [Track]?
    private var cachedAt: Date = .distantPast
    private let cacheLifetime: TimeInterval = 300

    func authenticate() async throws {}
    func logout() async throws {}

    func search(query: String) async throws -> [Track] {
        let library = try await getLibrary()
        let lowerQuery = query.lowercased()
        return library.filter { track in
            track.title.lowercased().contains(lowerQuery) ||
            track.artist.lowercased().contains(lowerQuery) ||
            track.album.lowercased().contains(lowerQuery)
        }
    }

    func getTrack(id: String) async throws -> Track {
        guard let url = URL(string: id), fileManager.fileExists(atPath: url.path) else {
            throw ProviderError.trackNotFound
        }
        return try await parseTrack(at: url)
    }

    func getStreamURL(for track: Track) async throws -> URL {
        guard let url = track.streamURL else {
            throw ProviderError.streamUnavailable
        }
        return url
    }

    private nonisolated func collectAudioFiles(from directory: URL) -> [URL] {
        var urls: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            while let fileURL = enumerator.nextObject() as? URL {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    urls.append(fileURL)
                }
            }
        }
        return urls
    }
    
    func getLibrary() async throws -> [Track] {
        if let cachedLibrary, Date().timeIntervalSince(cachedAt) < cacheLifetime {
            return cachedLibrary
        }

        guard let musicDir = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first else {
            return []
        }

        // Collect URLs synchronously first
        let fileURLs = collectAudioFiles(from: musicDir)

        // Then parse them asynchronously
        var tracks: [Track] = []
        for url in fileURLs {
            if let track = try? await parseTrack(at: url) {
                tracks.append(track)
            }
        }

        cachedLibrary = tracks
        cachedAt = Date()
        return tracks
    }

    func getPlaylists() async throws -> [Playlist] {
        return []
    }

    func createPlaylist(name: String) async throws -> Playlist {
        throw ProviderError.networkError("Playlists not supported by LocalFileProvider")
    }

    func addTrackToPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("Playlists not supported by LocalFileProvider")
    }

    func removeTrackFromPlaylist(playlist: Playlist, track: Track) async throws {
        throw ProviderError.networkError("Playlists not supported by LocalFileProvider")
    }

    func deletePlaylist(playlist: Playlist) async throws {
        throw ProviderError.networkError("Playlists not supported by LocalFileProvider")
    }

    private func parseTrack(at url: URL) async throws -> Track {
        let asset = AVAsset(url: url)

        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artworkURL: URL? = nil

        do {
            let metadata = try await asset.load(.metadata)

            for item in metadata {
                guard let key = item.commonKey?.rawValue else { continue }

                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    if let val = try await item.load(.stringValue) { title = val }
                case AVMetadataKey.commonKeyArtist.rawValue:
                    if let val = try await item.load(.stringValue) { artist = val }
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    if let val = try await item.load(.stringValue) { album = val }
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    if let data = try await item.load(.dataValue) {
                        // In a real app we'd save this data to a temp dir and return the URL
                        // For now we'll skip local artwork extraction
                    }
                default: break
                }
            }
        } catch {
            // Ignore metadata errors, use filename
        }

        let duration = try await asset.load(.duration).seconds

        return Track(
            id: "local-\(url.absoluteString)",
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkURL: artworkURL,
            streamURL: url,
            providerType: .local,
            providerTrackId: url.absoluteString
        )
    }
}
