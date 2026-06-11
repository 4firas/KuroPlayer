import Foundation
import AppKit
import AuthenticationServices

class AuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthManager()

    @Published var isAuthenticatedYouTubeMusic = false
    @Published var isAuthenticatedSoundCloud = false
    @Published var isAuthenticatedLastFm = false

    override private init() {
        super.init()
        loadSavedState()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
    }

    func startOAuth(url: URL, callbackScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: ProviderError.notAuthenticated)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func loadSavedState() {
        isAuthenticatedYouTubeMusic = YouTubeMusicAuth.shared.isSignedIn
        isAuthenticatedSoundCloud = SoundCloudAuth.shared.accessToken != nil
        isAuthenticatedLastFm = LastFmAuth.shared.sessionKey != nil
    }

    func refreshState() {
        loadSavedState()
    }

    func setAuthenticated(_ provider: MusicProviderType, value: Bool) {
        switch provider {
        case .youtubeMusic: isAuthenticatedYouTubeMusic = value
        case .soundcloud: isAuthenticatedSoundCloud = value
        case .local: break // Local files don't need auth
        }
    }

    func setLastFmAuthenticated(_ value: Bool) {
        isAuthenticatedLastFm = value
    }
}
