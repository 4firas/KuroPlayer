import Foundation
import MediaPlayer
import AppKit

@MainActor class MediaKeyHandler {
    static let shared = MediaKeyHandler()

    private var artworkTask: Task<Void, Never>?

    private init() {}

    func setup(engine: PlaybackEngine) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            engine.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            engine.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { try? await engine.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            Task { try? await engine.next() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            Task { try? await engine.previous() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                engine.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    func updateNowPlaying(track: Track?, isPlaying: Bool, currentTime: TimeInterval) {
        var info = [String: Any]()

        if let track = track {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyAlbumTitle] = track.album
            info[MPMediaItemPropertyPlaybackDuration] = track.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Fetch artwork asynchronously
        artworkTask?.cancel()
        if let url = track?.artworkURL {
            artworkTask = Task.detached {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let nsImage = NSImage(data: data),
                      !Task.isCancelled else { return }

                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                
                await MainActor.run {
                    var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                }
            }
        }
    }
}
