import Foundation

class Cache {
    static let shared = Cache()

    private let cacheDir: URL
    private let queue = DispatchQueue(label: "com.kuroplayer.cache", attributes: .concurrent)

    private init() {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = cachesDirectory.appendingPathComponent("KuroPlayerCache")

        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }

    func setObject<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval = 1800) {
        queue.async(flags: .barrier) {
            let wrapper = CacheWrapper(value: object, expirationDate: Date().addingTimeInterval(ttl))
            do {
                let data = try JSONEncoder().encode(wrapper)
                let fileURL = self.cacheDir.appendingPathComponent(self.hash(key))
                try data.write(to: fileURL)
            } catch {
                print("Cache write error: \(error)")
            }
        }
    }

    func getObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        return queue.sync {
            let fileURL = cacheDir.appendingPathComponent(hash(key))
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

            do {
                let data = try Data(contentsOf: fileURL)
                let wrapper = try JSONDecoder().decode(CacheWrapper<T>.self, from: data)

                if Date() < wrapper.expirationDate {
                    return wrapper.value
                } else {
                    try? FileManager.default.removeItem(at: fileURL) // Clean up expired
                    return nil
                }
            } catch {
                return nil
            }
        }
    }

    private func hash(_ string: String) -> String {
        return Data(string.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
    }

    private struct CacheWrapper<T: Codable>: Codable {
        let value: T
        let expirationDate: Date
    }
}
