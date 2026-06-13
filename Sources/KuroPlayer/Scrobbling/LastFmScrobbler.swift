import Foundation
import CryptoKit

@MainActor class LastFmScrobbler {
    static let shared = LastFmScrobbler()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "lastfm_api_key") ?? "YOUR_LASTFM_API_KEY"
    }
    private var apiSecret: String {
        UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? "YOUR_LASTFM_API_SECRET"
    }
    private let apiBaseURL = "https://ws.audioscrobbler.com/2.0/"
    
    private var offlineScrobbles: [(Track, Int)] = []
    
    private init() {}
    
    func scrobble(track: Track, timestamp: Int) async {
        guard let sessionKey = LastFmAuth.shared.sessionKey else { return }
        
        var params: [String: String] = [
            "method": "track.scrobble",
            "api_key": apiKey,
            "sk": sessionKey,
            "artist": track.artist,
            "track": track.title,
            "timestamp": String(timestamp)
        ]
        
        if !track.album.isEmpty {
            params["album"] = track.album
        }
        
        let sig = generateSignature(params: params)
        params["api_sig"] = sig
        params["format"] = "json"
        
        do {
            guard let url = URL(string: apiBaseURL) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Scrobbled: \(track.title) by \(track.artist)")
                await retryOfflineScrobbles()
            } else {
                offlineScrobbles.append((track, timestamp))
            }
        } catch {
            print("Scrobble error: \(error), caching for later.")
            offlineScrobbles.append((track, timestamp))
        }
    }
    
    private func retryOfflineScrobbles() async {
        guard !offlineScrobbles.isEmpty else { return }
        let queue = offlineScrobbles
        offlineScrobbles.removeAll()
        for (track, timestamp) in queue {
            await scrobble(track: track, timestamp: timestamp)
        }
    }
    
    func updateNowPlaying(track: Track) async {
        guard let sessionKey = LastFmAuth.shared.sessionKey else { return }
        
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "api_key": apiKey,
            "sk": sessionKey,
            "artist": track.artist,
            "track": track.title,
            "duration": String(Int(track.duration))
        ]
        
        if !track.album.isEmpty {
            params["album"] = track.album
        }
        
        let sig = generateSignature(params: params)
        params["api_sig"] = sig
        params["format"] = "json"
        
        do {
            guard let url = URL(string: apiBaseURL) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Now playing: \(track.title) by \(track.artist)")
            }
        } catch {
            print("Now playing error: \(error)")
        }
    }
    
    private func generateSignature(params: [String: String]) -> String {
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
}
