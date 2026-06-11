import Foundation
import AVFoundation
import Combine

@MainActor
protocol PlaybackEngineProtocol: ObservableObject {
    var state: PlaybackState { get set }
    func play(track: Track) async throws
    func playQueue(at index: Int) async throws
    func pause()
    func resume()
    func togglePlayPause() async throws
    func next() async throws
    func previous() async throws
    func seek(to time: TimeInterval)
    func setVolume(_ volume: Float)
    func toggleShuffle()
    func cycleRepeatMode()
    func setQueue(_ tracks: [Track])
    func addToQueue(_ track: Track)
}

class PlaybackEngine: PlaybackEngineProtocol {
    @Published var state = PlaybackState() {
        didSet {
            debouncedSave()
        }
    }
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var scrobbleTracker = ScrobbleTracker()
    private var saveTask: Task<Void, Never>?
    
    // Shared instance removed to fix singleton architecture
    // Injected via environment object instead
    
    init() {
        setupAudioSession()
        // Restore state asynchronously to avoid blocking init
        Task { @MainActor in
            self.restoreState()
        }
    }
    
    private func setupAudioSession() {
        #if os(macOS)
        // macOS doesn't need audio session setup like iOS
        #endif
    }
    
    private func getPersistenceURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KuroPlayer")

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent("playback_state.json")
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds debounce
            guard !Task.isCancelled else { return }
            self.saveState()
        }
    }

    private func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: getPersistenceURL())
        } catch {
            print("Failed to save playback state: \(error)")
        }
    }

    private func restoreState() {
        do {
            let data = try Data(contentsOf: getPersistenceURL())
            let restoredState = try JSONDecoder().decode(PlaybackState.self, from: data)
            
            // Restore metadata only - don't prepare tracks
            self.state.currentTrack = restoredState.currentTrack
            self.state.queue = restoredState.queue
            self.state.currentIndex = restoredState.currentIndex
            self.state.volume = restoredState.volume
            self.state.isShuffled = restoredState.isShuffled
            self.state.repeatMode = restoredState.repeatMode
            self.state.currentTime = restoredState.currentTime
            
            // Always start paused - user can resume manually
            self.state.status = .stopped
        } catch {
            print("Failed to restore playback state: \(error)")
        }
    }

    private func prepareTrack(track: Track) async throws {
        guard let provider = ProviderRegistry.shared.provider(for: track.providerType) else {
            throw ProviderError.streamUnavailable
        }
        
        let streamURL: URL
        // Re-fetch stream URL dynamically to avoid expiration
        streamURL = try await provider.getStreamURL(for: track)
        
        let playerItem = AVPlayerItem(url: streamURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.volume = state.volume
        addPeriodicTimeObserver()
    }

    func play(track: Track) async throws {
        state.status = .loading

        try await prepareTrack(track: track)

        state.currentTrack = track
        state.status = .playing

        audioPlayer?.play()
        
        scrobbleTracker.startTracking(track: track)
        updateMediaKeys()
    }
    
    func playQueue(at index: Int = 0) async throws {
        guard index < state.queue.count else { return }
        state.currentIndex = index
        try await play(track: state.queue[index])
    }
    
    func moveQueue(from source: IndexSet, to destination: Int) {
        state.queue.move(fromOffsets: source, toOffset: destination)
        // If the current playing track index shifted, we should ideally update currentIndex,
        // but for a simple queue, this is often enough.
    }

    func pause() {
        audioPlayer?.pause()
        state.status = .paused
        scrobbleTracker.pause()
        updateMediaKeys()
    }
    
    func resume() {
        audioPlayer?.play()
        state.status = .playing
        scrobbleTracker.resume()
        updateMediaKeys()
    }
    
    func togglePlayPause() async throws {
        switch state.status {
        case .playing:
            pause()
        case .paused, .stopped:
            resume()
            if audioPlayer == nil, let track = state.currentTrack {
               try await play(track: track)
            }
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
    
    private func updateMediaKeys() {
        MediaKeyHandler.shared.updateNowPlaying(
            track: state.currentTrack,
            isPlaying: state.status == .playing,
            currentTime: state.currentTime
        )
    }

    private func addPeriodicTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.state.currentTime = time.seconds
            
            if self.state.status == .playing {
                self.scrobbleTracker.updateProgress(time: time.seconds)
                // Update media keys occasionally to keep elapsed time somewhat accurate
                if Int(time.seconds) % 5 == 0 {
                    self.updateMediaKeys()
                }
            }
            
            // Auto-advance when track ends
            if let duration = self.state.currentTrack?.duration,
               time.seconds >= duration - 1 {
                Task {
                    try? await self.next()
                }
            }
        }
    }
    
    // Cleanup handled automatically by AVPlayer
}

class ScrobbleTracker {
    private var currentTrack: Track?
    private var actualListenTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var hasScrobbled = false
    private var scrobbleThreshold: TimeInterval = 0
    private var isTracking = false
    
    func startTracking(track: Track) {
        currentTrack = track
        actualListenTime = 0
        lastUpdateTime = 0
        hasScrobbled = false
        isTracking = true
        // Last.fm: scrobble at 50% or 4 minutes, whichever comes first
        scrobbleThreshold = min(track.duration * 0.5, 240)
    }
    
    func pause() {
        isTracking = false
    }

    func resume() {
        isTracking = true
    }

    func updateProgress(time: TimeInterval) {
        guard isTracking, let track = currentTrack, !hasScrobbled else {
            lastUpdateTime = time
            return
        }

        let delta = max(0, time - lastUpdateTime)
        actualListenTime += delta
        lastUpdateTime = time
        
        if actualListenTime >= scrobbleThreshold {
            Task {
                await LastFmScrobbler.shared.scrobble(track: track)
            }
            hasScrobbled = true
        } else if actualListenTime >= 30 && actualListenTime - delta < 30 {
            // Send "now playing" once after 30 seconds of actual listening
            Task {
                await LastFmScrobbler.shared.updateNowPlaying(track: track)
            }
        }
    }
}
