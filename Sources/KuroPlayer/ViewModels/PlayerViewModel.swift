import Foundation
import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var isLoadingTrack = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var queue: [Track] = []
    @Published var currentQueueIndex = 0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var searchResults: [Track] = []
    @Published var libraryTracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedView: MainView = .home

    // Scrubbing: non-nil while the user drags the progress bar.
    @Published var scrubFraction: Double?

    // Playlist import
    @Published var playlistImportText = ""
    @Published var isImportingPlaylist = false
    @Published var importStatusMessage: String?

    let playbackEngine: PlaybackEngine
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(playbackEngine: PlaybackEngine) {
        self.playbackEngine = playbackEngine
        setupBindings()
    }

    private func setupBindings() {
        playbackEngine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.currentTrack = state.currentTrack
                self?.isPlaying = state.status == .playing
                self?.isLoadingTrack = state.status == .loading
                self?.currentTime = state.currentTime
                self?.duration = state.currentTrack?.duration ?? 0
                self?.volume = state.volume
                self?.queue = state.queue
                self?.currentQueueIndex = state.currentIndex
                self?.isShuffled = state.isShuffled
                self?.repeatMode = state.repeatMode
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback

    func play(track: Track) {
        Task {
            do {
                try await playbackEngine.play(track: track)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Plays `tracks[index]` and queues the whole list, so next/previous
    /// behave the same from search, library and playlists.
    func playFromList(_ tracks: [Track], startingAt index: Int) {
        guard tracks.indices.contains(index) else { return }
        playbackEngine.setQueue(tracks)
        playQueue(at: index)
    }

    func playShuffled(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        playbackEngine.setQueue(tracks.shuffled())
        playQueue(at: 0)
    }

    func togglePlayPause() {
        Task {
            do {
                try await playbackEngine.togglePlayPause()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func next() {
        Task {
            do {
                try await playbackEngine.next()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func previous() {
        Task {
            do {
                try await playbackEngine.previous()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func seek(to time: TimeInterval) {
        playbackEngine.seek(to: time)
    }

    func setVolume(_ volume: Float) {
        playbackEngine.setVolume(volume)
    }

    func toggleShuffle() {
        playbackEngine.toggleShuffle()
    }

    func cycleRepeatMode() {
        playbackEngine.cycleRepeatMode()
    }

    func playQueue(at index: Int) {
        Task {
            do {
                try await playbackEngine.playQueue(at: index)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setQueue(_ tracks: [Track]) {
        playbackEngine.setQueue(tracks)
    }

    func addToQueue(_ track: Track) {
        playbackEngine.addToQueue(track)
    }

    func clearQueue() {
        playbackEngine.clearQueue()
    }

    func moveQueue(from source: IndexSet, to destination: Int) {
        playbackEngine.moveQueue(from: source, to: destination)
    }

    // MARK: - Search (debounced)

    /// Called on every keystroke; waits 350 ms of quiet before hitting
    /// yt-dlp, and cancels the in-flight search (terminating its processes)
    /// when the query changes.
    func searchTextChanged(_ query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // Playlist links get an import card instead of a search.
        if detectPlaylistURL(in: trimmed) != nil {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: trimmed)
        }
    }

    /// Immediate search (Return key) — skips the debounce.
    func searchNow() {
        searchTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, detectPlaylistURL(in: trimmed) == nil else { return }
        searchTask = Task { [weak self] in
            await self?.performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        let results = await ProviderRegistry.shared.searchAllProviders(query: query)
        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false
    }

    // MARK: - Playlist import

    /// Returns the URL if `text` is a playlist link one of the providers can
    /// import (SoundCloud set, YouTube/YouTube Music playlist).
    func detectPlaylistURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("http"), let url = URL(string: trimmed) else { return nil }
        guard ProviderRegistry.shared.playlistImportProvider(for: url) != nil else { return nil }
        return url
    }

    func importPlaylist(from urlString: String) {
        guard !isImportingPlaylist else { return }
        guard let url = detectPlaylistURL(in: urlString) else {
            errorMessage = "That link doesn't look like a SoundCloud set or a YouTube playlist."
            return
        }

        Task {
            isImportingPlaylist = true
            importStatusMessage = "Fetching playlist…"
            defer {
                isImportingPlaylist = false
                importStatusMessage = nil
            }

            do {
                guard let provider = ProviderRegistry.shared.playlistImportProvider(for: url) else { return }
                importStatusMessage = "Resolving tracks — this can take a moment for large playlists…"
                let playlist = try await provider.importPlaylist(url: url)
                PlaylistStore.shared.upsert(playlist)
                playlistImportText = ""
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines) == urlString.trimmingCharacters(in: .whitespacesAndNewlines) {
                    searchText = ""
                }
                selectedView = .playlist(playlist.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Re-syncs an imported playlist from its source URL.
    func refreshPlaylist(_ playlist: Playlist) {
        guard let source = playlist.sourceURL else { return }
        importPlaylist(from: source.absoluteString)
    }

    func removePlaylist(_ playlist: Playlist) {
        PlaylistStore.shared.remove(id: playlist.id)
        if selectedView == .playlist(playlist.id) {
            selectedView = .playlists
        }
    }

    // MARK: - Library

    func loadLibrary() async {
        var allTracks: [Track] = []
        var allPlaylists: [Playlist] = []

        for provider in ProviderRegistry.shared.authenticatedProviders() {
            do {
                let tracks = try await provider.getLibrary()
                allTracks.append(contentsOf: tracks)

                let playlists = try await provider.getPlaylists()
                allPlaylists.append(contentsOf: playlists)
            } catch {
                print("Error loading from \(provider.type): \(error)")
            }
        }

        libraryTracks = allTracks
        playlists = allPlaylists
    }

    func dismissError() {
        errorMessage = nil
    }

    func authenticateProvider(_ type: MusicProviderType) async {
        do {
            guard let provider = ProviderRegistry.shared.provider(for: type) else { return }
            try await provider.authenticate()
            AuthManager.shared.refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logoutProvider(_ type: MusicProviderType) async {
        do {
            guard let provider = ProviderRegistry.shared.provider(for: type) else { return }
            try await provider.logout()
            AuthManager.shared.refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
