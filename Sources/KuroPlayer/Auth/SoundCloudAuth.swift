import Foundation
import CryptoKit

@MainActor class SoundCloudAuth {
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
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    func authenticate() async throws {
        guard clientID != "YOUR_SOUNDCLOUD_CLIENT_ID", clientSecret != "YOUR_SOUNDCLOUD_CLIENT_SECRET" else {
            throw ProviderError.networkError("Please set your SoundCloud Client ID and Secret in Settings > API Keys.")
        }
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString
        
        let authURLString = "https://secure.soundcloud.com/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(encodedRedirect)&scope=\(encodedScopes)&code_challenge=\(codeChallenge)&code_challenge_method=S256&state=\(state)"
        
        guard let authURL = URL(string: authURLString) else {
            throw ProviderError.invalidResponse
        }
        
        let callbackURL = try await AuthManager.shared.startOAuth(url: authURL, callbackScheme: "kuroplayer")
        
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw ProviderError.notAuthenticated
        }
        
        try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
        AuthManager.shared.setAuthenticated(.soundcloud, value: true)
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        guard let tokenURL = URL(string: "https://secure.soundcloud.com/oauth/token") else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=authorization_code&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(redirectURI)&code_verifier=\(codeVerifier)&code=\(code)"
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
              let tokenURL = URL(string: "https://secure.soundcloud.com/oauth/token") else {
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

