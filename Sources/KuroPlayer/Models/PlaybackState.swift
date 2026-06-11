import Foundation

enum PlaybackStatus: Codable {
    case stopped
    case playing
    case paused
    case loading
}

enum RepeatMode: Int, Codable {
    case off
    case all
    case one
}

struct PlaybackState: Codable {
    var currentTrack: Track?
    var queue: [Track] = []
    var currentIndex: Int = 0
    var status: PlaybackStatus = .stopped
    var currentTime: TimeInterval = 0
    var volume: Float = 0.7
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off

    var nextTrack: Track? {
        guard !queue.isEmpty else { return nil }
        let nextIndex = currentIndex + 1
        if nextIndex < queue.count {
            return queue[nextIndex]
        } else if repeatMode == .all {
            return queue.first
        }
        return nil
    }

    var previousTrack: Track? {
        guard !queue.isEmpty else { return nil }
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            return queue[prevIndex]
        } else if repeatMode == .all {
            return queue.last
        }
        return nil
    }
}
