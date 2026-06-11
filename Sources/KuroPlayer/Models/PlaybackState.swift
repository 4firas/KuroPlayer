import Foundation

enum PlaybackStatus {
    case stopped
    case playing
    case paused
    case loading
}

struct PlaybackState {
    var currentTrack: Track?
    var queue: [Track] = []
    var currentIndex: Int = 0
    var status: PlaybackStatus = .stopped
    var currentTime: TimeInterval = 0
    var volume: Float = 0.7
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off

    enum RepeatMode {
        case off
        case all
        case one
    }

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
