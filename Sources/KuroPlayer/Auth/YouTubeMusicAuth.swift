import Foundation

class YouTubeMusicAuth {
    static let shared = YouTubeMusicAuth()
    
    private let clientID = "YOUR_GOOGLE_CLIENT_ID"
    private let redirectURI = "kuroplayer://youtubemusic-callback"
    
    var isSignedIn: Bool {
        return true // Search and stream work without OAuth via yt-dlp
    }
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "youtubemusic_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtubemusic_access_token") }
    }
    
    var hasFullAuth: Bool {
        accessToken != nil
    }
    
    func authenticate() async throws {
        // Google OAuth for YouTube Data API (library/playlists access)
        let scopes = "https://www.googleapis.com/auth/youtube.readonly"
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&response_type=code&redirect_uri=\(encodedRedirect)&scope=\(encodedScopes)&access_type=offline&prompt=consent"
        
        guard let authURL = URL(string: authURLString) else {
            throw ProviderError.invalidResponse
        }
        
        let callbackURL = try await AuthManager.shared.startOAuth(url: authURL, callbackScheme: "kuroplayer")
        
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ProviderError.notAuthenticated
        }
        
        try await exchangeCodeForToken(code)
    }
    
    private func exchangeCodeForToken(_ code: String) async throws {
        // Token exchange requires client_secret — skip for now (search/stream works anyway)
        // Full Google OAuth implementation would go here
        print("YouTube Music OAuth code received: \(code.prefix(10))...")
    }
    
    func logout() {
        accessToken = nil
    }
}
