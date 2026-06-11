import Foundation
import AVFoundation
import Combine

class PlaybackEngine: ObservableObject {
    @Published var state = PlaybackState()
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var scrobbleTracker = ScrobbleTracker()
    
    static let shared = PlaybackEngine()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if os(macOS)
        // macOS doesn't need audio session setup like iOS
        #endif
    }
    
    func play(track: Track) async throws {
        guard let provider = ProviderRegistry.shared.provider(for: track.providerType) else {
            throw ProviderError.streamUnavailable
        }
        
        state.status = .loading
        
        let streamURL: URL
        if track.providerType == .soundcloud, let url = track.streamURL {
            streamURL = url
        } else {
            streamURL = try await provider.getStreamURL(for: track)
        }
        
        state.currentTrack = track
        state.status = .playing
        
        let playerItem = AVPlayerItem(url: streamURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.volume = state.volume
        
        addPeriodicTimeObserver()
        audioPlayer?.play()
        
        scrobbleTracker.startTracking(track: track)
    }
    
    func playQueue(at index: Int = 0) async throws {
        guard index < state.queue.count else { return }
        state.currentIndex = index
        try await play(track: state.queue[index])
    }
    
    func pause() {
        audioPlayer?.pause()
        state.status = .paused
    }
    
    func resume() {
        audioPlayer?.play()
        state.status = .playing
    }
    
    func togglePlayPause() async throws {
        switch state.status {
        case .playing:
            pause()
        case .paused:
            resume()
        default:
            break
        }
    }
    
    func next() async throws {
        if state.repeatMode == .one {
            try await playQueue(at: state.currentIndex)
        } else if let nextTrack = state.nextTrack {
            state.currentIndex += 1
            try await play(track: nextTrack)
        }
    }
    
    func previous() async throws {
        if state.currentTime > 3 {
            // If more than 3 seconds in, restart current track
            seek(to: 0)
        } else if let prevTrack = state.previousTrack {
            state.currentIndex -= 1
            try await play(track: prevTrack)
        }
    }
    
    func seek(to time: TimeInterval) {
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: targetTime)
        state.currentTime = time
    }
    
    func setVolume(_ volume: Float) {
        state.volume = volume
        audioPlayer?.volume = volume
    }
    
    func toggleShuffle() {
        state.isShuffled.toggle()
        if state.isShuffled {
            state.queue.shuffle()
        }
    }
    
    func cycleRepeatMode() {
        switch state.repeatMode {
        case .off:
            state.repeatMode = .all
        case .all:
            state.repeatMode = .one
        case .one:
            state.repeatMode = .off
        }
    }
    
    func setQueue(_ tracks: [Track]) {
        state.queue = tracks
        state.currentIndex = 0
    }
    
    func addToQueue(_ track: Track) {
        state.queue.append(track)
    }
    
    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.state.currentTime = time.seconds
            
            self.scrobbleTracker.updateProgress(time: time.seconds)
            
            // Auto-advance when track ends
            if let duration = self.state.currentTrack?.duration,
               time.seconds >= duration - 1 {
                Task {
                    try? await self.next()
                }
            }
        }
    }
    
    deinit {
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
        }
    }
}

class ScrobbleTracker {
    private var currentTrack: Track?
    private var playStartTime: Date?
    private var hasScrobbled = false
    private var scrobbleThreshold: TimeInterval = 0
    
    func startTracking(track: Track) {
        currentTrack = track
        playStartTime = Date()
        hasScrobbled = false
        // Last.fm: scrobble at 50% or 4 minutes, whichever comes first
        scrobbleThreshold = min(track.duration * 0.5, 240)
    }
    
    func updateProgress(time: TimeInterval) {
        guard let track = currentTrack, !hasScrobbled else { return }
        
        if time >= scrobbleThreshold {
            Task {
                await LastFmScrobbler.shared.scrobble(track: track)
            }
            hasScrobbled = true
        } else if time >= 30 {
            // Send "now playing" after 30 seconds
            Task {
                await LastFmScrobbler.shared.updateNowPlaying(track: track)
            }
        }
    }
}
