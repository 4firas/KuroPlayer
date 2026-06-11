import Foundation

class YouTubeMusicAuth {
    static let shared = YouTubeMusicAuth()
    
    private var clientID: String {
        UserDefaults.standard.string(forKey: "youtube_client_id") ?? "YOUR_GOOGLE_CLIENT_ID"
    }
    private var clientSecret: String {
        UserDefaults.standard.string(forKey: "youtube_client_secret") ?? "YOUR_GOOGLE_CLIENT_SECRET"
    }
    private let redirectURI = "http://127.0.0.1:8080/callback" // Google OAuth macOS desktop standard loopback
    
    var isSignedIn: Bool {
        return true // Search and stream work without OAuth via yt-dlp
    }
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "youtubemusic_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtubemusic_access_token") }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "youtubemusic_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "youtubemusic_refresh_token") }
    }

    var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "youtubemusic_token_expiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "youtubemusic_token_expiry") }
    }

    var hasFullAuth: Bool {
        return accessToken != nil
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
