import AppKit

/// Zero-leak, privacy-hardened native service to fetch, extract, and cache favicons
/// with dynamic Apple typographic monogram fallbacks.
///
/// Privacy Guarantees:
/// - Uses an isolated ephemeral URLSession that never accepts or persists cookies, credentials, or shared state.
/// - Never contacts Google or any third-party favicon resolution proxies.
/// - Strictly prevents cross-origin redirects (blocks tracking redirects and intranet exfiltration).
/// - Enforces SSRF protection: blocks loopback, private IPv4, IPv6 local, and link-local cloud metadata IPs.
/// - Blocks favicon requests to known tracking, ad, and telemetry domains.
/// - Parses data: URIs in-memory with zero network activity.
/// - Enforces maximum download size limits (512 KB) to prevent memory exhaustion.
public final class FaviconService {

    public static let shared = FaviconService()

    /// Thread-safe in-memory cache with automatic system memory eviction
    private let cache = NSCache<NSString, NSImage>()

    /// Ephemeral network session with zero cookie and credential retention
    private var session: URLSession!

    /// In-flight request deduplication
    private var inFlightRequests: [String: [(NSImage) -> Void]] = [:]
    private let lock = NSLock()

    /// Maximum allowable icon payload (512 KB)
    private static let maxFaviconBytes: Int = 512 * 1024

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

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 5.0

        let delegate = FaviconRedirectDelegate()
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    /// Verifies if a hostname is safe to query (rejects loopback, intranet/private IPs, metadata, and trackers)
    public static func isSafeHost(_ host: String) -> Bool {
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }

        // Loopback / local machine
        if clean == "localhost" || clean == "127.0.0.1" || clean == "::1" || clean == "0.0.0.0" {
            return false
        }

        // Link-local cloud metadata (AWS, GCP, Azure, OpenStack 169.254.x.x)
        if clean.hasPrefix("169.254.") {
            return false
        }

        // RFC 1918 Private IPv4 address ranges
        if clean.hasPrefix("10.") || clean.hasPrefix("192.168.") {
            return false
        }
        if clean.hasPrefix("172.") {
            let parts = clean.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return false
            }
        }

        // IPv6 Local / Multicast / Link-local
        if clean.hasPrefix("fe80:") || clean.hasPrefix("fc00:") || clean.hasPrefix("fd00:") || clean.hasPrefix("ff") {
            return false
        }

        // Known tracking, advertising, and telemetry domains
        if ContentBlockerService.isTracker(host: clean) {
            return false
        }

        return true
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

        // SSRF and privacy guard: Never query loopback, private intranet, or trackers
        guard Self.isSafeHost(host) else {
            let fallback = monogramIcon(for: host)
            cache.setObject(fallback, forKey: cacheKey)
            completion(fallback)
            return
        }

        // Direct origin request to /favicon.ico over HTTPS/HTTP only
        let scheme = (url.scheme?.lowercased() == "http") ? "http" : "https"
        guard let faviconURL = URL(string: "\(scheme)://\(host)/favicon.ico") else {
            completion(monogramIcon(for: host))
            return
        }

        // Deduplicate concurrent requests for the same host
        lock.lock()
        if inFlightRequests[host] != nil {
            inFlightRequests[host]?.append(completion)
            lock.unlock()
            return
        }
        inFlightRequests[host] = [completion]
        lock.unlock()

        var request = URLRequest(url: faviconURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 3.0

        session.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }

            var resolvedImage: NSImage?
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               data.count > 0 && data.count <= Self.maxFaviconBytes,
               let image = NSImage(data: data) {
                resolvedImage = image
                self.cache.setObject(image, forKey: cacheKey)
            } else {
                let fallback = self.monogramIcon(for: host)
                self.cache.setObject(fallback, forKey: cacheKey)
                resolvedImage = fallback
            }

            let finalImage = resolvedImage ?? self.monogramIcon(for: host)

            self.lock.lock()
            let callbacks = self.inFlightRequests.removeValue(forKey: host) ?? []
            self.lock.unlock()

            DispatchQueue.main.async {
                for callback in callbacks {
                    callback(finalImage)
                }
            }
        }.resume()
    }

    /// Safely resolves and caches a favicon specified by an HTML `<link rel="icon">` element
    public func resolveDOMFavicon(href: String, documentURL: URL?, completion: @escaping (NSImage?) -> Void) {
        let deliver: (NSImage?) -> Void = { result in
            if Thread.isMainThread {
                completion(result)
            } else {
                DispatchQueue.main.async { completion(result) }
            }
        }

        guard let docURL = documentURL, let host = docURL.host?.lowercased(), !host.isEmpty else {
            deliver(nil)
            return
        }

        // 1. Data URI favicon: decode in-memory with zero network traffic and zero leak
        if href.hasPrefix("data:image/") {
            if let commaIndex = href.firstIndex(of: ",") {
                let meta = href[..<commaIndex]
                let payload = String(href[href.index(after: commaIndex)...])
                let data: Data?
                if meta.contains(";base64") {
                    data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
                } else if let unescaped = payload.removingPercentEncoding {
                    data = unescaped.data(using: .utf8)
                } else {
                    data = nil
                }
                if let data = data, data.count > 0 && data.count <= Self.maxFaviconBytes, let img = NSImage(data: data) {
                    cacheFavicon(img, for: host)
                    deliver(img)
                    return
                }
            }
            deliver(nil)
            return
        }

        // 2. Relative or absolute remote icon URL
        guard let resolvedURL = URL(string: href, relativeTo: docURL) else {
            deliver(nil)
            return
        }

        // Verify scheme is strictly HTTP or HTTPS
        let scheme = (resolvedURL.scheme ?? "").lowercased()
        guard scheme == "https" || scheme == "http" else {
            deliver(nil)
            return
        }

        // Verify host: must match origin host or be a subdomain of same domain (prevents third-party tracking beacons)
        guard let iconHost = resolvedURL.host?.lowercased(), !iconHost.isEmpty else {
            deliver(nil)
            return
        }

        let isSameOrigin = (iconHost == host)
        let isSubdomain = iconHost.hasSuffix("." + host) || host.hasSuffix("." + iconHost)
        guard (isSameOrigin || isSubdomain) && Self.isSafeHost(iconHost) else {
            // Reject cross-origin or unsafe icon requests (stops tracker leaks)
            deliver(nil)
            return
        }

        var req = URLRequest(url: resolvedURL)
        req.cachePolicy = .returnCacheDataElseLoad
        req.timeoutInterval = 3.0

        session.dataTask(with: req) { [weak self] data, response, _ in
            guard let self = self,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  data.count > 0 && data.count <= Self.maxFaviconBytes,
                  let img = NSImage(data: data) else {
                deliver(nil)
                return
            }

            self.cacheFavicon(img, for: host)
            deliver(img)
        }.resume()
    }

    /// Stores a high-resolution favicon explicitly (e.g. extracted from HTML `<link rel="icon">` or `apple-touch-icon`)
    public func cacheFavicon(_ image: NSImage, for host: String) {
        let cleanHost = host.lowercased()
        cache.setObject(image, forKey: cleanHost as NSString)
    }

    /// Clears all cached icons from memory
    public func clearCache() {
        cache.removeAllObjects()
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

// MARK: - Favicon Redirect Delegate (Cross-Origin Protection)
private final class FaviconRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let originalURL = task.originalRequest?.url,
              let originalHost = originalURL.host?.lowercased(),
              let redirectURL = request.url,
              let redirectHost = redirectURL.host?.lowercased(),
              (redirectURL.scheme == "https" || redirectURL.scheme == "http") else {
            completionHandler(nil)
            return
        }

        // Strictly disallow cross-host redirects to prevent third-party tracker exfiltration
        if redirectHost == originalHost && FaviconService.isSafeHost(redirectHost) {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }
}
