import Foundation

class ProviderRegistry {
    static let shared = ProviderRegistry()
    
    private var providers: [MusicProviderType: MusicProvider] = [:]
    
    private init() {
        providers[.youtubeMusic] = YouTubeMusicProvider()
        providers[.soundcloud] = SoundCloudProvider()
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
    
    func searchAllProviders(query: String) async -> [Track] {
        var allTracks: [Track] = []
        
        await withTaskGroup(of: [Track].self) { group in
            for provider in authenticatedProviders() {
                group.addTask {
                    do {
                        return try await provider.search(query: query)
                    } catch {
                        print("Search error for \(provider.type): \(error)")
                        return []
                    }
                }
            }
            
            for await tracks in group {
                allTracks.append(contentsOf: tracks)
            }
        }
        
        return allTracks
    }
}
