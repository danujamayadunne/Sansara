import AppKit

/// Simple, lightweight service to fetch and cache favicons with system SF Symbol fallbacks.
public final class FaviconService {

    public static let shared = FaviconService()

    /// Memory cache for favicons keyed by hostname
    private var cache: [String: NSImage] = [:]
    private let cacheLock = NSLock()

    /// Default fallback icon using SF Symbol
    public static var defaultIcon: NSImage {
        if let img = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web") {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            return img.withSymbolConfiguration(config) ?? img
        }
        return NSImage()
    }

    private init() {}

    /// Retrieves a cached favicon or fetches asynchronously.
    public func getFavicon(for url: URL?, completion: @escaping (NSImage) -> Void) {
        guard let url = url, let host = url.host?.lowercased(), !host.isEmpty else {
            completion(Self.defaultIcon)
            return
        }

        cacheLock.lock()
        if let cached = cache[host] {
            cacheLock.unlock()
            completion(cached)
            return
        }
        cacheLock.unlock()

        // Asynchronously fetch favicon
        // Using Google's reliable public favicon resolution service
        guard let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            completion(Self.defaultIcon)
            return
        }

        let request = URLRequest(url: faviconURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = NSImage(data: data) else {
                DispatchQueue.main.async {
                    completion(Self.defaultIcon)
                }
                return
            }

            self.cacheLock.lock()
            self.cache[host] = image
            self.cacheLock.unlock()

            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    /// Store a favicon explicitly (e.g. if extracted from HTML `<link rel="icon">`)
    public func cacheFavicon(_ image: NSImage, for host: String) {
        cacheLock.lock()
        cache[host.lowercased()] = image
        cacheLock.unlock()
    }
}
