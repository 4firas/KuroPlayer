import Foundation

@MainActor class ProviderRegistry {
    static let shared = ProviderRegistry()

    private var providers: [MusicProviderType: MusicProvider] = [:]

    private init() {
        providers[.youtubeMusic] = YouTubeMusicProvider()
        providers[.soundcloud] = SoundCloudProvider()
        providers[.local] = LocalFileProvider()
    }

    func provider(for type: MusicProviderType) -> MusicProvider? {
        return providers[type]
    }

    func allProviders() -> [MusicProvider] {
        return Array(providers.values)
    }

    func authenticatedProviders() -> [MusicProvider] {
        return providers.values.filter { $0.isAuthenticated }
    }

    /// First provider that recognizes `url` as an importable playlist
    /// (SoundCloud set, YouTube/YouTube Music playlist, …).
    func playlistImportProvider(for url: URL) -> MusicProvider? {
        return providers.values.first { $0.canImportPlaylist(url: url) }
    }

    func searchAllProviders(query: String) async -> [Track] {
        var allTracks: [Track] = []

        await withTaskGroup(of: (MusicProviderType, [Track]).self) { group in
            for provider in authenticatedProviders() {
                let providerType = provider.type
                group.addTask {
                    do {
                        return (providerType, try await provider.search(query: query))
                    } catch is CancellationError {
                        return (providerType, [])
                    } catch {
                        print("Search error for \(providerType): \(error)")
                        return (providerType, [])
                    }
                }
            }

            for await (_, tracks) in group {
                allTracks.append(contentsOf: tracks)
            }
        }

        return allTracks
    }
}
