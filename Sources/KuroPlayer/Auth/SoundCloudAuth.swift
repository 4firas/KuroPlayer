import Foundation

class SoundCloudAuth {
    static let shared = SoundCloudAuth()
    
    private var clientID: String {
        UserDefaults.standard.string(forKey: "soundcloud_client_id") ?? "YOUR_SOUNDCLOUD_CLIENT_ID"
    }
    private var clientSecret: String {
        UserDefaults.standard.string(forKey: "soundcloud_client_secret") ?? "YOUR_SOUNDCLOUD_CLIENT_SECRET"
    }
    private let redirectURI = "kuroplayer://soundcloud-callback"
    private let scopes = "*"
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "soundcloud_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "soundcloud_access_token") }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "soundcloud_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "soundcloud_refresh_token") }
    }
    
    func authenticate() async throws {
        guard clientID != "YOUR_SOUNDCLOUD_CLIENT_ID", clientSecret != "YOUR_SOUNDCLOUD_CLIENT_SECRET" else {
            throw ProviderError.networkError("Please set your SoundCloud Client ID and Secret in Settings > API Keys.")
        }
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = "https://secure.soundcloud.com/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(encodedRedirect)&scope=\(encodedScopes)"
        
        guard let authURL = URL(string: authURLString) else {
            throw ProviderError.invalidResponse
        }
        
        let callbackURL = try await AuthManager.shared.startOAuth(url: authURL, callbackScheme: "kuroplayer")
        
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ProviderError.notAuthenticated
        }
        
        try await exchangeCodeForToken(code)
        await AuthManager.shared.setAuthenticated(.soundcloud, value: true)
    }
    
    private func exchangeCodeForToken(_ code: String) async throws {
        guard let tokenURL = URL(string: "https://api.soundcloud.com/oauth2/token") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=authorization_code&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(redirectURI)&code=\(code)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Token exchange failed")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let token = json?["access_token"] as? String else {
            throw ProviderError.invalidResponse
        }
        
        accessToken = token
        refreshToken = json?["refresh_token"] as? String
    }
    
    func refreshAccessToken() async throws {
        guard let refresh = refreshToken,
              let tokenURL = URL(string: "https://api.soundcloud.com/oauth2/token") else {
            throw ProviderError.notAuthenticated
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=refresh_token&client_id=\(clientID)&client_secret=\(clientSecret)&refresh_token=\(refresh)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Token refresh failed")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let token = json?["access_token"] as? String else {
            throw ProviderError.invalidResponse
        }
        
        accessToken = token
        if let newRefresh = json?["refresh_token"] as? String {
            refreshToken = newRefresh
        }
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        AuthManager.shared.isAuthenticatedSoundCloud = false
    }
}
