import Foundation

/// Utility for detecting whether input text is a direct URL or a search query,
/// and converting it to a valid destination URL.
public enum URLHelper {

    /// Google search base URL
    private static let searchEndpoint = "https://www.google.com/search?q="

    /// Resolves raw text into a valid target URL (direct URL or search query)
    public static func resolve(input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return URL(string: "https://www.google.com")!
        }

        // 1. Direct scheme: http:// or https:// or file://
        if trimmed.lowercased().hasPrefix("http://") ||
           trimmed.lowercased().hasPrefix("https://") ||
           trimmed.lowercased().hasPrefix("file://") {
            if let url = URL(string: trimmed), url.host != nil || trimmed.hasPrefix("file://") {
                return url
            }
        }

        // 2. Localhost or IP with port check
        if trimmed.lowercased().hasPrefix("localhost") || trimmed.hasPrefix("127.0.0.1") {
            let prefixed = "http://" + trimmed
            if let url = URL(string: prefixed) {
                return url
            }
        }

        // 3. Check if text looks like a domain name (no whitespace, contains at least one dot, valid TLD/host structure)
        if !trimmed.contains(" ") && trimmed.contains(".") {
            // Check if there are invalid characters for a host
            let hostCandidate = trimmed.components(separatedBy: "/").first ?? trimmed
            let hostParts = hostCandidate.components(separatedBy: ".")
            if hostParts.count >= 2, let tld = hostParts.last, tld.count >= 2, !tld.contains(":") || hostCandidate.contains(":") {
                let prefixed = "https://" + trimmed
                if let url = URL(string: prefixed), url.host != nil {
                    return url
                }
            }
        }

        // 4. Default to search query
        let queryAllowed = CharacterSet.urlQueryAllowed
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? trimmed
        return URL(string: searchEndpoint + encoded) ?? URL(string: "https://www.google.com")!
    }

    /// Prettifies a URL for clean display in the address bar (e.g. omitting https:// for clarity)
    public static func displayString(for url: URL?) -> String {
        guard let url = url, let string = url.absoluteString.removingPercentEncoding else {
            return ""
        }
        return string
    }
}
