import Foundation
import CryptoKit

@MainActor class LastFmAuth {
    static let shared = LastFmAuth()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "lastfm_api_key") ?? "YOUR_LASTFM_API_KEY"
    }
    private var apiSecret: String {
        UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? "YOUR_LASTFM_API_SECRET"
    }
    private let apiBaseURL = "https://ws.audioscrobbler.com/2.0/"
    
    var sessionKey: String? {
        get { UserDefaults.standard.string(forKey: "lastfm_session_key") }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_session_key") }
    }
    
    var username: String? {
        get { UserDefaults.standard.string(forKey: "lastfm_username") }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_username") }
    }
    
    func authenticate() async throws {
        guard apiKey != "YOUR_LASTFM_API_KEY", apiSecret != "YOUR_LASTFM_API_SECRET" else {
            throw ProviderError.networkError("Please set your Last.fm API key and secret in Settings before connecting.")
        }
        let callbackURL = "kuroplayer://lastfm-callback"
        let encodedCallback = callbackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = "https://www.last.fm/api/auth/?api_key=\(apiKey)&cb=\(encodedCallback)"
        
        guard let authURL = URL(string: authURLString) else {
            throw ProviderError.invalidResponse
        }
        
        let resultURL = try await AuthManager.shared.startOAuth(url: authURL, callbackScheme: "kuroplayer")
        
        guard let components = URLComponents(url: resultURL, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            throw ProviderError.notAuthenticated
        }
        
        try await getSession(token: token)
        AuthManager.shared.setLastFmAuthenticated(true)
    }
    
    private func getSession(token: String) async throws {
        var params: [String: String] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        
        let sig = generateSignature(params: params)
        params["api_sig"] = sig
        params["format"] = "json"
        
        guard let url = URL(string: apiBaseURL) else {
            throw ProviderError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkError("Failed to get session")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let session = json?["session"] as? [String: Any],
              let key = session["key"] as? String,
              let name = session["name"] as? String else {
            throw ProviderError.invalidResponse
        }
        
        sessionKey = key
        username = name
    }
    
    func generateSignature(params: [String: String]) -> String {
        let sorted = params.sorted { $0.key < $1.key }
        var sigString = ""
        for (key, value) in sorted {
            sigString += key + value
        }
        sigString += apiSecret
        
        return Insecure.MD5.hash(data: sigString.data(using: .utf8)!)
            .map { String(format: "%02hhx", $0) }
            .joined()
    }
    
    func logout() {
        sessionKey = nil
        username = nil
        AuthManager.shared.setLastFmAuthenticated(false)
    }
}
