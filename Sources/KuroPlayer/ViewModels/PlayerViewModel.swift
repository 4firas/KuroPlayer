import Foundation
import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var queue: [Track] = []
    @Published var searchResults: [Track] = []
    @Published var libraryTracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedView: MainView = .home
    @Published var sliderVolume: Double = 0.7
    
    let playbackEngine: PlaybackEngine
    private var cancellables = Set<AnyCancellable>()
    
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
                self?.currentTime = state.currentTime
                self?.duration = state.currentTrack?.duration ?? 0
                self?.volume = state.volume
                self?.queue = state.queue
            }
            .store(in: &cancellables)
    }
    
    func play(track: Track) {
        Task {
            do {
                try await playbackEngine.play(track: track)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
    
    func moveQueue(from source: IndexSet, to destination: Int) {
        playbackEngine.moveQueue(from: source, to: destination)
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        let results = await ProviderRegistry.shared.searchAllProviders(query: query)
        searchResults = results
        isSearching = false
    }
    
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
