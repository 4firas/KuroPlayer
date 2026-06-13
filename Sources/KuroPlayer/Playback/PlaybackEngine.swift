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

    /// Single AVPlayer for the app's lifetime; tracks are swapped with
    /// replaceCurrentItem(with:) per Apple's recommended pattern. This also
    /// means the periodic time observer is attached exactly once.
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var scrobbleTracker = ScrobbleTracker()
    private var saveTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    /// Identifies the most recent play request so a slow stream resolution
    /// can't clobber a newer one (rapid track switching).
    private var playRequestID = UUID()

    init() {
        addPeriodicTimeObserver()
        // Restore state asynchronously to avoid blocking init
        Task { @MainActor in
            self.restoreState()
        }
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
            self.state.unshuffledQueue = restoredState.unshuffledQueue
            self.state.repeatMode = restoredState.repeatMode
            self.state.currentTime = restoredState.currentTime

            // Always start paused - user can resume manually
            self.state.status = .stopped
            player.volume = restoredState.volume
        } catch {
            print("Failed to restore playback state: \(error)")
        }
    }

    // MARK: - Playback

    private func prepareTrack(track: Track) async throws {
        let streamURL: URL
        if track.providerType == .local {
            guard let localURL = track.streamURL else { throw ProviderError.streamUnavailable }
            streamURL = localURL
        } else if let localPath = UserDataStore.shared.downloadedTracks[track.id], FileManager.default.fileExists(atPath: localPath) {
            streamURL = URL(fileURLWithPath: localPath)
        } else {
            guard let provider = ProviderRegistry.shared.provider(for: track.providerType) else {
                throw ProviderError.streamUnavailable
            }
            streamURL = try await provider.getStreamURL(for: track)
        }

        let asset = AVURLAsset(url: streamURL)
        let playerItem = AVPlayerItem(asset: asset)

        // Route audio through the parametric EQ tap. Attached even while the
        // EQ is disabled so enabling it mid-track takes effect immediately;
        // a disabled EQ is all-bands-bypassed (pass-through).
        if let audioMix = await EQAudioTap.makeAudioMix(for: asset) {
            playerItem.audioMix = audioMix
        }

        observeItem(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.volume = state.volume
    }

    func play(track: Track) async throws {
        let requestID = UUID()
        playRequestID = requestID

        state.status = .loading
        state.currentTrack = track
        state.currentTime = 0
        // Keep currentIndex in sync when the track lives in the queue.
        if let queueIndex = state.queue.firstIndex(of: track) {
            state.currentIndex = queueIndex
        }
        updateMediaKeys()

        do {
            try await prepareTrack(track: track)
        } catch {
            // Never leave the UI stuck on "loading" after a failure.
            if playRequestID == requestID {
                state.status = .stopped
            }
            throw error
        }

        // A newer play request superseded this one while we were resolving.
        guard playRequestID == requestID else { return }

        state.status = .playing
        player.play()

        scrobbleTracker.startTracking(track: track)
        updateMediaKeys()
        prefetchNextStreamURL()
    }

    func playQueue(at index: Int = 0) async throws {
        guard index >= 0, index < state.queue.count else { return }
        state.currentIndex = index
        try await play(track: state.queue[index])
    }

    func moveQueue(from source: IndexSet, to destination: Int) {
        let current = state.currentTrack
        state.queue.move(fromOffsets: source, toOffset: destination)
        if let current, let index = state.queue.firstIndex(of: current) {
            state.currentIndex = index
        }
    }

    func pause() {
        player.pause()
        state.status = .paused
        scrobbleTracker.pause()
        updateMediaKeys()
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.play()
        state.status = .playing
        scrobbleTracker.resume()
        updateMediaKeys()
    }

    func togglePlayPause() async throws {
        switch state.status {
        case .playing:
            pause()
        case .paused:
            resume()
        case .stopped:
            // After a restart or queue end there's no usable item/position —
            // start the track fresh; otherwise just resume.
            if player.currentItem != nil, state.currentTime > 0 {
                resume()
            } else if let track = state.currentTrack {
                try await play(track: track)
            }
        case .loading:
            break
        }
    }

    func next() async throws {
        guard !state.queue.isEmpty else { return }

        let nextIndex = state.currentIndex + 1
        if nextIndex < state.queue.count {
            state.currentIndex = nextIndex
            try await play(track: state.queue[nextIndex])
        } else if state.repeatMode != .off {
            state.currentIndex = 0
            try await play(track: state.queue[0])
        } else {
            player.pause()
            state.status = .stopped
            state.currentTime = 0
            updateMediaKeys()
        }
    }

    func previous() async throws {
        if state.currentTime > 3 {
            // If more than 3 seconds in, restart current track
            seek(to: 0)
            return
        }

        guard !state.queue.isEmpty else { return }

        let prevIndex = state.currentIndex - 1
        if prevIndex >= 0 {
            state.currentIndex = prevIndex
            try await play(track: state.queue[prevIndex])
        } else if state.repeatMode == .all {
            state.currentIndex = state.queue.count - 1
            try await play(track: state.queue[state.currentIndex])
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        state.currentTime = time
        scrobbleTracker.noteSeek(to: time)
        updateMediaKeys()
    }

    func setVolume(_ volume: Float) {
        state.volume = volume
        player.volume = volume
    }

    func toggleShuffle() {
        if state.isShuffled {
            if let original = state.unshuffledQueue {
                let current = state.currentTrack
                state.queue = original
                if let current, let index = original.firstIndex(of: current) {
                    state.currentIndex = index
                } else {
                    state.currentIndex = 0
                }
            }
            state.unshuffledQueue = nil
            state.isShuffled = false
        } else {
            state.unshuffledQueue = state.queue
            let current = state.currentTrack
            state.queue.shuffle()
            // Keep the playing track at the front so "next" is fresh.
            if let current, let index = state.queue.firstIndex(of: current) {
                state.queue.swapAt(0, index)
            }
            state.currentIndex = 0
            state.isShuffled = true
        }
        prefetchNextStreamURL()
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
        state.isShuffled = false
        state.unshuffledQueue = nil
    }

    func addToQueue(_ track: Track) {
        state.queue.append(track)
    }

    func clearQueue() {
        // Keep the playing track so playback isn't interrupted.
        if let current = state.currentTrack {
            state.queue = [current]
        } else {
            state.queue = []
        }
        state.currentIndex = 0
        state.isShuffled = false
        state.unshuffledQueue = nil
    }

    // MARK: - Item observation

    private func observeItem(_ item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failObserver {
            NotificationCenter.default.removeObserver(failObserver)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleTrackEnded()
            }
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.state.status = .stopped
            }
        }
    }

    private func handleTrackEnded() {
        if state.repeatMode == .one {
            seek(to: 0)
            player.play()
            state.status = .playing
            if let track = state.currentTrack {
                scrobbleTracker.startTracking(track: track)
            }
            updateMediaKeys()
        } else {
            Task {
                try? await self.next()
            }
        }
    }

    /// Warms the stream-URL cache for the upcoming track so pressing next
    /// (or auto-advance) starts near-instantly.
    private func prefetchNextStreamURL() {
        prefetchTask?.cancel()
        guard let nextTrack = state.nextTrack, nextTrack.providerType != .local else { return }

        prefetchTask = Task { @MainActor in
            guard let provider = ProviderRegistry.shared.provider(for: nextTrack.providerType) else { return }
            _ = try? await provider.getStreamURL(for: nextTrack)
        }
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
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        guard time.isNumeric else { return }
        state.currentTime = time.seconds

        if state.status == .playing {
            scrobbleTracker.updateProgress(time: time.seconds)
            // Update media keys occasionally to keep elapsed time somewhat accurate
            if Int(time.seconds) % 5 == 0 {
                updateMediaKeys()
            }
        }
    }
}

class ScrobbleTracker {
    private var currentTrack: Track?
    private var actualListenTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var playStartTime: Int = 0
    private var hasScrobbled = false
    private var scrobbleThreshold: TimeInterval = 0
    private var isTracking = false

    func startTracking(track: Track) {
        currentTrack = track
        actualListenTime = 0
        lastUpdateTime = 0
        playStartTime = Int(Date().timeIntervalSince1970)
        hasScrobbled = false
        isTracking = true
        // Last.fm: scrobble at 50% or 4 minutes, whichever comes first
        scrobbleThreshold = min(track.duration * 0.5, 240)
        
        // Immediately notify "Now Playing" when tracking starts
        Task {
            await LastFmScrobbler.shared.updateNowPlaying(track: track)
        }
    }

    func pause() {
        isTracking = false
    }

    func resume() {
        isTracking = true
    }

    /// Seeking must not count as listening time in either direction.
    func noteSeek(to time: TimeInterval) {
        lastUpdateTime = time
    }

    func updateProgress(time: TimeInterval) {
        guard isTracking, let track = currentTrack, !hasScrobbled else {
            lastUpdateTime = time
            return
        }

        // Anything above ~2s between ticks is a seek or a stall, not listening.
        let delta = time - lastUpdateTime
        lastUpdateTime = time
        guard delta > 0, delta < 2 else { return }
        actualListenTime += delta

        if actualListenTime >= scrobbleThreshold {
            let timestamp = playStartTime
            Task {
                await LastFmScrobbler.shared.scrobble(track: track, timestamp: timestamp)
            }
            hasScrobbled = true
        }
    }
}
