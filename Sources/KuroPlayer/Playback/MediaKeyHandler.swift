import Foundation
import MediaPlayer

@MainActor class MediaKeyHandler {
    static let shared = MediaKeyHandler()

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
    }

    func updateNowPlaying(track: Track?, isPlaying: Bool, currentTime: TimeInterval) {
        var nowPlayingInfo = [String: Any]()

        if let track = track {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

            // Note: In a real implementation we would fetch the artwork asynchronously
            // and update the info center again once loaded.
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
