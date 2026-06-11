import Foundation
import AVFoundation

class LocalFileProvider: MusicProvider {
    var type: MusicProviderType { .local }
    var isAuthenticated: Bool { true }

    private let fileManager = FileManager.default
    private let supportedExtensions = ["mp3", "m4a", "flac", "wav"]

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

    func getLibrary() async throws -> [Track] {
        guard let musicDir = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first else {
            return []
        }

        var tracks: [Track] = []
        if let enumerator = fileManager.enumerator(at: musicDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    if let track = try? await parseTrack(at: fileURL) {
                        tracks.append(track)
                    }
                }
            }
        }

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
