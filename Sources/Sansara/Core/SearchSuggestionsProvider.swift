import Foundation

// MARK: - Suggestion Data Models

public enum SuggestionKind: String, Codable, Equatable {
    case history = "History"
    case verifiedDomain = "Verified Domain"
}

/// Unified search suggestion model for history records and verified domains.
public struct SearchSuggestion: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let url: URL
    public let displayURL: String
    public let kind: SuggestionKind
    public let visitDate: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        url: URL,
        displayURL: String? = nil,
        kind: SuggestionKind = .history,
        visitDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.displayURL = displayURL ?? SearchSuggestionsProvider.displayString(for: url)
        self.kind = kind
        self.visitDate = visitDate
    }

    public init(historyItem: HistoryItem) {
        self.init(
            id: historyItem.id.uuidString,
            title: historyItem.title,
            url: historyItem.url,
            displayURL: SearchSuggestionsProvider.displayString(for: historyItem.url),
            kind: .history,
            visitDate: historyItem.visitDate
        )
    }

    public init(verifiedDomain: VerifiedDomain) {
        self.init(
            id: verifiedDomain.displayDomain,
            title: verifiedDomain.name,
            url: verifiedDomain.url,
            displayURL: verifiedDomain.displayDomain,
            kind: .verifiedDomain,
            visitDate: nil
        )
    }
}

// MARK: - Verified Domains

/// Curated verified domains for top popular websites (e.g. x.com, youtube, google, reddit, twitch, apple, github, facebook, instagram).
public struct VerifiedDomain: Equatable {
    public let name: String
    public let urlString: String
    public let displayDomain: String
    public let keywords: [String]

    public var url: URL {
        URL(string: urlString) ?? URL(string: "https://\(displayDomain)")!
    }

    public init(name: String, urlString: String, displayDomain: String, keywords: [String]) {
        self.name = name
        self.urlString = urlString
        self.displayDomain = displayDomain
        self.keywords = keywords
    }

    public static let standard: [VerifiedDomain] = [
        VerifiedDomain(
            name: "X",
            urlString: "https://x.com",
            displayDomain: "x.com",
            keywords: ["x", "x.com", "twitter", "twitter.com"]
        ),
        VerifiedDomain(
            name: "YouTube",
            urlString: "https://www.youtube.com",
            displayDomain: "youtube.com",
            keywords: ["youtube", "youtube.com", "yt", "you"]
        ),
        VerifiedDomain(
            name: "Google",
            urlString: "https://www.google.com",
            displayDomain: "google.com",
            keywords: ["google", "google.com", "goo"]
        ),
        VerifiedDomain(
            name: "Reddit",
            urlString: "https://www.reddit.com",
            displayDomain: "reddit.com",
            keywords: ["reddit", "reddit.com", "red"]
        ),
        VerifiedDomain(
            name: "Twitch",
            urlString: "https://www.twitch.tv",
            displayDomain: "twitch.tv",
            keywords: ["twitch", "twitch.tv", "twi"]
        ),
        VerifiedDomain(
            name: "Apple",
            urlString: "https://www.apple.com",
            displayDomain: "apple.com",
            keywords: ["apple", "apple.com", "app"]
        ),
        VerifiedDomain(
            name: "GitHub",
            urlString: "https://github.com",
            displayDomain: "github.com",
            keywords: ["github", "github.com", "git"]
        ),
        VerifiedDomain(
            name: "Facebook",
            urlString: "https://www.facebook.com",
            displayDomain: "facebook.com",
            keywords: ["facebook", "facebook.com", "fb", "face"]
        ),
        VerifiedDomain(
            name: "Instagram",
            urlString: "https://www.instagram.com",
            displayDomain: "instagram.com",
            keywords: ["instagram", "instagram.com", "insta", "ig"]
        )
    ]

    /// Checks if this verified domain matches the input query.
    public func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        let domainLower = displayDomain.lowercased()
        let nameLower = name.lowercased()

        if domainLower.hasPrefix(q) || domainLower.contains(q) {
            return true
        }
        if nameLower.hasPrefix(q) || nameLower.contains(q) {
            return true
        }
        if keywords.contains(where: { $0.hasPrefix(q) || $0 == q }) {
            return true
        }
        return false
    }

    /// Match score for ranking: lower score = stronger match
    public func matchScore(query: String) -> Int {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let domainLower = displayDomain.lowercased()
        let nameLower = name.lowercased()

        if domainLower == q || nameLower == q || keywords.contains(where: { $0 == q }) {
            return 1
        }
        if domainLower.hasPrefix(q) || nameLower.hasPrefix(q) || keywords.contains(where: { $0.hasPrefix(q) }) {
            return 2
        }
        if domainLower.contains(q) || nameLower.contains(q) {
            return 3
        }
        return 4
    }
}

// MARK: - Search Suggestions Provider

/// Provides top 5 ranked, deduplicated history searches, with verified domain fallback for according websites.
public final class SearchSuggestionsProvider {

    public static let shared = SearchSuggestionsProvider()

    private let historyManager: HistoryManager
    private let verifiedDomains: [VerifiedDomain]

    public init(
        historyManager: HistoryManager = .shared,
        verifiedDomains: [VerifiedDomain] = VerifiedDomain.standard
    ) {
        self.historyManager = historyManager
        self.verifiedDomains = verifiedDomains
    }

    /// Formats a URL for clean user-facing display by removing schemes and trailing slashes.
    public static func displayString(for url: URL) -> String {
        var str = url.absoluteString
        if str.hasPrefix("https://") {
            str = String(str.dropFirst(8))
        } else if str.hasPrefix("http://") {
            str = String(str.dropFirst(7))
        }
        if str.hasSuffix("/") {
            str = String(str.dropLast())
        }
        return str
    }

    /// Normalizes URL string for deduplication (ignoring trailing slash and lowercase).
    public static func normalizeURLKey(for url: URL) -> String {
        var str = url.absoluteString.lowercased()
        if str.hasSuffix("/") {
            str = String(str.dropLast())
        }
        return str
    }

    /// Returns matching verified domains sorted by relevance to query.
    public func matchingVerifiedDomains(for query: String) -> [VerifiedDomain] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return verifiedDomains }

        return verifiedDomains
            .filter { $0.matches(query: trimmed) }
            .sorted { (a, b) -> Bool in
                let scoreA = a.matchScore(query: trimmed)
                let scoreB = b.matchScore(query: trimmed)
                if scoreA != scoreB {
                    return scoreA < scoreB
                }
                return a.name < b.name
            }
    }

    /// Returns top history items matching the user's typing query (deduplicated and ranked).
    public func historySuggestions(for query: String, maxCount: Int = 5) -> [HistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryLower = trimmed.lowercased()
        let queryTokens = queryLower.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty else { return [] }

        let allItems = historyManager.allHistory()

        // Deduplicate by normalized URL (preserving the most recent visit)
        var seenURLs = Set<String>()
        var uniqueItems: [HistoryItem] = []
        for item in allItems {
            let key = Self.normalizeURLKey(for: item.url)
            if !seenURLs.contains(key) {
                seenURLs.insert(key)
                uniqueItems.append(item)
            }
        }

        struct ScoredItem {
            let item: HistoryItem
            let score: Int
        }

        var scoredItems: [ScoredItem] = []

        for item in uniqueItems {
            let hostLower = item.url.host?.lowercased() ?? ""
            let hostWithoutWWW = hostLower.hasPrefix("www.") ? String(hostLower.dropFirst(4)) : hostLower
            let titleLower = item.title.lowercased()
            let urlLower = item.url.absoluteString.lowercased()
            let displayLower = Self.displayString(for: item.url).lowercased()

            let matchesAllTokens = queryTokens.allSatisfy { token in
                titleLower.contains(token) ||
                urlLower.contains(token) ||
                hostLower.contains(token)
            }

            guard matchesAllTokens else { continue }

            let score: Int
            if hostWithoutWWW.hasPrefix(queryLower) || hostLower.hasPrefix(queryLower) {
                score = 1
            } else if hostWithoutWWW.contains(queryLower) || hostLower.contains(queryLower) {
                score = 2
            } else if displayLower.hasPrefix(queryLower) || urlLower.hasPrefix(queryLower) {
                score = 3
            } else if titleLower.hasPrefix(queryLower) {
                score = 4
            } else if titleLower.contains(queryLower) {
                score = 5
            } else {
                score = 6
            }

            scoredItems.append(ScoredItem(item: item, score: score))
        }

        scoredItems.sort { (a, b) -> Bool in
            if a.score != b.score {
                return a.score < b.score
            }
            return a.item.visitDate > b.item.visitDate
        }

        return Array(scoredItems.map { $0.item }.prefix(maxCount))
    }

    /// Primary search suggestion endpoint:
    /// - Shows top 5 searches/history.
    /// - If not in search history, shows verified domains for according websites (x.com, youtube, google, reddit, twitch, apple, github, facebook, instagram).
    public func suggestions(for query: String, maxCount: Int = 5) -> [SearchSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty query: top 5 recent searches, or if no search history, top 5 verified domains
        if trimmed.isEmpty {
            let recent = historyManager.recentHistory(limit: maxCount * 2)
            var seen = Set<String>()
            var historyResults: [SearchSuggestion] = []
            for item in recent {
                let key = Self.normalizeURLKey(for: item.url)
                if !seen.contains(key) {
                    seen.insert(key)
                    historyResults.append(SearchSuggestion(historyItem: item))
                }
                if historyResults.count >= maxCount { break }
            }

            if !historyResults.isEmpty {
                return historyResults
            } else {
                // If not in search history: show verified domains!
                return Array(verifiedDomains.prefix(maxCount)).map { SearchSuggestion(verifiedDomain: $0) }
            }
        }

        // Non-empty query:
        let historyMatches = historySuggestions(for: trimmed, maxCount: maxCount)
        let matchingVerified = matchingVerifiedDomains(for: trimmed)

        // Avoid showing a verified domain if the user already has that exact host in their top history results
        let historyHosts = Set(historyMatches.compactMap { $0.url.host?.lowercased() })
        let filteredVerified = matchingVerified.filter { domain in
            let host = domain.url.host?.lowercased() ?? domain.displayDomain.lowercased()
            let hostWithoutWWW = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return !historyHosts.contains(host) &&
                   !historyHosts.contains("www.\(host)") &&
                   !historyHosts.contains(hostWithoutWWW)
        }

        var results: [SearchSuggestion] = []

        // If not found in search history: show verified domain for according websites!
        if historyMatches.isEmpty {
            for domain in filteredVerified.prefix(maxCount) {
                results.append(SearchSuggestion(verifiedDomain: domain))
            }
            return results
        }

        // If history has matches:
        // If query has a strong prefix match for a verified domain (e.g. typing "x", "you", "git"),
        // include the verified domain at the top so the user can easily reach the official site
        let queryLower = trimmed.lowercased()
        let topVerified = filteredVerified.first { domain in
            domain.displayDomain.lowercased().hasPrefix(queryLower) ||
            domain.keywords.contains(where: { $0 == queryLower })
        }

        if let verified = topVerified {
            results.append(SearchSuggestion(verifiedDomain: verified))
        }

        for item in historyMatches {
            if results.count >= maxCount { break }
            results.append(SearchSuggestion(historyItem: item))
        }

        // If still room, append any other matching verified domains up to maxCount (5)
        for domain in filteredVerified {
            if results.count >= maxCount { break }
            if !results.contains(where: { $0.displayURL == domain.displayDomain }) {
                results.append(SearchSuggestion(verifiedDomain: domain))
            }
        }

        return Array(results.prefix(maxCount))
    }
}
