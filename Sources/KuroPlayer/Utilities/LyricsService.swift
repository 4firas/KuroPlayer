import Foundation

/// Fetches lyrics from lrclib.net. Supports synced (LRC) and plain text lyrics.
@MainActor
class LyricsService {
    static let shared = LyricsService()

    private var cache: [String: LyricsResult] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "KuroPlayer/1.0 (https://github.com/kuroplayer)"
        ]
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    struct LyricLine: Identifiable {
        let id = UUID()
        let time: TimeInterval
        let text: String
    }

    enum LyricsResult {
        case synced([LyricLine])
        case plain(String)
        case none
    }

    func fetchLyrics(title: String, artist: String, duration: TimeInterval) async -> LyricsResult {
        let cacheKey = "\(title.lowercased())|\(artist.lowercased())"
        if let cached = cache[cacheKey] { return cached }

        let cleanedTitle = cleanTitle(title)
        let superCleaned = superCleanTitle(title)
        let cleanedArtist = superCleanTitle(artist)

        // Strategy 1: Exact match
        if let result = await fetchExact(title: title, artist: artist, duration: duration) {
            cache[cacheKey] = result
            return result
        }
        if cleanedTitle != title {
            if let result = await fetchExact(title: cleanedTitle, artist: artist, duration: duration) {
                cache[cacheKey] = result
                return result
            }
        }

        // Strategy 2: Structured Search API (title + artist)
        if let result = await fetchSearch(title: title, artist: artist, targetDuration: duration) {
            cache[cacheKey] = result
            return result
        }
        if cleanedTitle != title {
            if let result = await fetchSearch(title: cleanedTitle, artist: artist, targetDuration: duration) {
                cache[cacheKey] = result
                return result
            }
        }
        if superCleaned != cleanedTitle || cleanedArtist != artist {
            if let result = await fetchSearch(title: superCleaned, artist: cleanedArtist, targetDuration: duration) {
                cache[cacheKey] = result
                return result
            }
        }
        
        // Strategy 3: Free-form query search API `q=...`
        if let result = await fetchSearchQuery(q: "\(cleanedArtist) \(superCleaned)", targetDuration: duration) {
            cache[cacheKey] = result
            return result
        }
        if let result = await fetchSearchQuery(q: superCleaned, targetDuration: duration) {
            cache[cacheKey] = result
            return result
        }

        // Strategy 4: Break title into phrases (e.g. "Anime OST - Song Title")
        let phrases = extractPhrases(from: superCleaned)
        for phrase in phrases {
            if let result = await fetchSearchQuery(q: "\(cleanedArtist) \(phrase)", targetDuration: duration) {
                cache[cacheKey] = result
                return result
            }
        }
        
        // Fallback to phrase-only without artist (since uploader might not be artist)
        for phrase in phrases {
            if let result = await fetchSearchQuery(q: phrase, targetDuration: duration) {
                cache[cacheKey] = result
                return result
            }
        }

        // Final fallback: try raw title in query search
        if let result = await fetchSearchQuery(q: title, targetDuration: duration) {
            cache[cacheKey] = result
            return result
        }

        cache[cacheKey] = LyricsResult.none
        return LyricsResult.none
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let patterns = [
            "(?i)\\s*\\[free download\\]",
            "(?i)\\s*\\(official audio\\)",
            "(?i)\\s*\\(official video\\)",
            "(?i)\\s*\\(lyric video\\)",
            "(?i)\\s*\\[lyric video\\]",
            "(?i)\\s*\\(audio\\)",
            "(?i)\\s*\\(music video\\)",
            "(?i)\\s*\\[official music video\\]",
            "(?i)\\s*\\[audio\\]"
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func superCleanTitle(_ text: String) -> String {
        var cleaned = text
        
        // Remove text in parentheses, brackets, braces
        let bracketPatterns = [
            "\\([^\\)]*\\)",
            "\\[[^\\]]*\\]",
            "\\{[^\\}]*\\}",
            "【[^】]*】",
            "「[^」]*」"
        ]
        for pattern in bracketPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove common keywords
        let keywords = [
            "official video", "official audio", "music video", "lyric video", 
            "audio", "video", "lyrics", "ost", "soundtrack", "theme", "opening", "ending", 
            "op", "ed", "full", "tv size", "instrumental", "vocal", "cover", "remix", 
            "feat.", "ft.", "featuring", "produced by", "prod."
        ]
        
        for keyword in keywords {
            cleaned = cleaned.replacingOccurrences(of: "(?i)\\b\(keyword)\\b", with: "", options: .regularExpression)
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func extractPhrases(from title: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: "-|~:;\"")
        let components = title.components(separatedBy: delimiters)
        return components
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 } // Ignore single letters or empty
    }

    // MARK: - API

    private func fetchExact(title: String, artist: String, duration: TimeInterval) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            if httpResponse.statusCode == 404 { return nil }
            guard httpResponse.statusCode == 200 else { return nil }

            return parseLyricsResponse(data)
        } catch {
            return nil
        }
    }

    private func fetchSearch(title: String, artist: String, targetDuration: TimeInterval) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        return await executeSearch(url: components.url, targetDuration: targetDuration)
    }
    
    private func fetchSearchQuery(q: String, targetDuration: TimeInterval) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: q)
        ]
        return await executeSearch(url: components.url, targetDuration: targetDuration)
    }

    private func executeSearch(url: URL?, targetDuration: TimeInterval) async -> LyricsResult? {
        guard let url = url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            
            // Filter out tracks without any lyrics
            let validTracks = array.filter { json in
                let hasSynced = (json["syncedLyrics"] as? String)?.isEmpty == false
                let hasPlain = (json["plainLyrics"] as? String)?.isEmpty == false
                let isInst = json["instrumental"] as? Bool == true
                return hasSynced || hasPlain || isInst
            }
            
            if validTracks.isEmpty { return nil }
            
            // Priority 1: Synced lyrics within 15 seconds of target duration
            if let bestMatch = validTracks.first(where: { json in
                let hasSynced = (json["syncedLyrics"] as? String)?.isEmpty == false
                guard let dur = json["duration"] as? Double else { return false }
                return hasSynced && abs(dur - targetDuration) <= 15
            }) {
                let matchData = try JSONSerialization.data(withJSONObject: bestMatch)
                return parseLyricsResponse(matchData)
            }
            
            // Priority 2: Any valid lyrics within 15 seconds of target duration
            if let closeMatch = validTracks.first(where: { json in
                guard let dur = json["duration"] as? Double else { return false }
                return abs(dur - targetDuration) <= 15
            }) {
                let matchData = try JSONSerialization.data(withJSONObject: closeMatch)
                return parseLyricsResponse(matchData)
            }
            
            // Priority 3: Highest ranked result with synced lyrics (ignoring duration)
            if let bestRankedSynced = validTracks.first(where: { json in
                let hasSynced = (json["syncedLyrics"] as? String)?.isEmpty == false
                return hasSynced
            }) {
                let matchData = try JSONSerialization.data(withJSONObject: bestRankedSynced)
                return parseLyricsResponse(matchData)
            }
            
            // Fallback: Just take the highest ranked valid result
            let firstData = try JSONSerialization.data(withJSONObject: validTracks[0])
            return parseLyricsResponse(firstData)
        } catch {
            return nil
        }
    }

    private func parseLyricsResponse(_ data: Data) -> LyricsResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Prefer synced lyrics
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            let lines = parseLRC(synced)
            if !lines.isEmpty { return .synced(lines) }
        }

        // Fallback to plain
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            return .plain(plain)
        }

        // Check if instrumental
        if let instrumental = json["instrumental"] as? Bool, instrumental {
            return .plain("♪ Instrumental ♪")
        }

        return nil
    }

    // MARK: - LRC Parser

    /// Parses LRC format: `[mm:ss.xx] lyrics text`
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = /\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)/

        for line in lrc.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if let match = trimmed.firstMatch(of: pattern) {
                let minutes = Double(match.1) ?? 0
                let seconds = Double(match.2) ?? 0
                let centiseconds = Double(match.3) ?? 0
                let divisor: Double = String(match.3).count == 3 ? 1000 : 100
                let time = minutes * 60 + seconds + centiseconds / divisor
                let text = String(match.4).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}
