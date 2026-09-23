import AppKit

/// Zero-leak, 100% native service to fetch, extract, and cache favicons
/// with dynamic Apple typographic monogram fallbacks.
public final class FaviconService {

    public static let shared = FaviconService()

    /// Thread-safe in-memory cache with automatic system memory eviction
    private let cache = NSCache<NSString, NSImage>()

    /// Default fallback icon using SF Symbol
    public static var defaultIcon: NSImage {
        if let img = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web") {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            return img.withSymbolConfiguration(config) ?? img
        }
        return NSImage()
    }

    private init() {
        cache.countLimit = 300
    }

    /// Retrieves a cached favicon or fetches directly from the origin host (zero third-party leak).
    public func getFavicon(for url: URL?, completion: @escaping (NSImage) -> Void) {
        guard let url = url, let host = url.host?.lowercased(), !host.isEmpty else {
            completion(Self.defaultIcon)
            return
        }

        let cacheKey = host as NSString
        if let cached = cache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        // Direct, private origin request to /favicon.ico (never contacting third-party trackers)
        let scheme = url.scheme ?? "https"
        guard let faviconURL = URL(string: "\(scheme)://\(host)/favicon.ico") else {
            completion(monogramIcon(for: host))
            return
        }

        var request = URLRequest(url: faviconURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               let image = NSImage(data: data) {
                self.cache.setObject(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                let fallback = self.monogramIcon(for: host)
                self.cache.setObject(fallback, forKey: cacheKey)
                DispatchQueue.main.async {
                    completion(fallback)
                }
            }
        }.resume()
    }

    /// Stores a high-resolution favicon explicitly (e.g. extracted from HTML `<link rel="icon">` or `apple-touch-icon`)
    public func cacheFavicon(_ image: NSImage, for host: String) {
        let cleanHost = host.lowercased()
        cache.setObject(image, forKey: cleanHost as NSString)
    }

    /// Generates a clean Apple typographic monogram disc using the host's primary initial
    public func monogramIcon(for host: String) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let clean = host.replacingOccurrences(of: "www.", with: "")
        let initial = String(clean.prefix(1)).uppercased()

        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 3.5, yRadius: 3.5)
        NSColor.quaternaryLabelColor.setFill()
        path.fill()

        let font = NSFont.systemFont(ofSize: 10, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let string = NSAttributedString(string: initial.isEmpty ? "•" : initial, attributes: attributes)
        let stringSize = string.size()
        let rect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        string.draw(in: rect)

        image.unlockFocus()
        return image
    }
}
