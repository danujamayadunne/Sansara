import Foundation

public struct BookmarkItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var url: URL
    public let dateAdded: Date
    public var folder: String?

    public init(id: UUID = UUID(), title: String, url: URL, dateAdded: Date = Date(), folder: String? = nil) {
        self.id = id
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = cleanTitle.isEmpty ? (url.host ?? url.absoluteString) : cleanTitle
        self.url = url
        self.dateAdded = dateAdded
        self.folder = folder
    }
}

public final class BookmarkManager: NSObject {

    public static let shared = BookmarkManager()

    public static let didUpdateNotification = Notification.Name("SansaraBookmarksDidUpdateNotification")

    private var items: [BookmarkItem] = []
    private let lock = NSLock()
    private let fileURL: URL?

    public init(fileURL: URL? = BookmarkManager.defaultStorageURL()) {
        self.fileURL = fileURL
        super.init()
        load()
    }

    public static func defaultStorageURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Sansara", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir.appendingPathComponent("bookmarks.json")
    }

    // MARK: - Core Operations

    public func allBookmarks() -> [BookmarkItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    public func isBookmarked(url: URL?) -> Bool {
        guard let url = url else { return false }
        lock.lock()
        defer { lock.unlock() }
        let normalizedTarget = normalizedURLString(for: url)
        return items.contains { normalizedURLString(for: $0.url) == normalizedTarget }
    }

    @discardableResult
    public func addBookmark(title: String, url: URL, folder: String? = nil) -> BookmarkItem {
        lock.lock()
        defer {
            lock.unlock()
            save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: BookmarkManager.didUpdateNotification, object: self)
            }
        }

        let normalizedTarget = normalizedURLString(for: url)
        if let existingIndex = items.firstIndex(where: { normalizedURLString(for: $0.url) == normalizedTarget }) {
            let existing = items[existingIndex]
            let updated = BookmarkItem(id: existing.id, title: title.isEmpty ? existing.title : title, url: url, dateAdded: existing.dateAdded, folder: folder ?? existing.folder)
            items[existingIndex] = updated
            return updated
        }

        let item = BookmarkItem(title: title, url: url, folder: folder)
        items.insert(item, at: 0)
        return item
    }

    @discardableResult
    public func toggleBookmark(title: String, url: URL) -> Bool {
        if isBookmarked(url: url) {
            removeBookmark(url: url)
            return false
        } else {
            addBookmark(title: title, url: url)
            return true
        }
    }

    public func removeBookmark(id: UUID) {
        lock.lock()
        items.removeAll(where: { $0.id == id })
        lock.unlock()
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: BookmarkManager.didUpdateNotification, object: self)
        }
    }

    public func removeBookmark(url: URL) {
        let target = normalizedURLString(for: url)
        lock.lock()
        items.removeAll(where: { normalizedURLString(for: $0.url) == target })
        lock.unlock()
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: BookmarkManager.didUpdateNotification, object: self)
        }
    }

    public func updateBookmark(id: UUID, title: String, url: URL, folder: String? = nil) {
        lock.lock()
        defer {
            lock.unlock()
            save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: BookmarkManager.didUpdateNotification, object: self)
            }
        }

        if let index = items.firstIndex(where: { $0.id == id }) {
            let existing = items[index]
            items[index] = BookmarkItem(id: id, title: title, url: url, dateAdded: existing.dateAdded, folder: folder)
        }
    }

    public func search(query: String) -> [BookmarkItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        defer { lock.unlock() }
        guard !trimmed.isEmpty else { return items }

        return items.filter { item in
            item.title.lowercased().contains(trimmed) ||
            item.url.absoluteString.lowercased().contains(trimmed) ||
            (item.folder?.lowercased().contains(trimmed) ?? false)
        }
    }

    public func clearAll() {
        lock.lock()
        items.removeAll()
        lock.unlock()
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: BookmarkManager.didUpdateNotification, object: self)
        }
    }

    private func normalizedURLString(for url: URL) -> String {
        var str = url.absoluteString.lowercased()
        if str.hasSuffix("/") {
            str.removeLast()
        }
        return str
    }

    // MARK: - Persistence

    private func save() {
        guard let url = fileURL else { return }
        lock.lock()
        let snapshot = items
        lock.unlock()

        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                // Ignore silent persistence errors in sandbox or fallback environments
            }
        }
    }

    private func load() {
        guard let url = fileURL else {
            populateDefaultBookmarksIfNeeded()
            return
        }

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode([BookmarkItem].self, from: data)
                lock.lock()
                self.items = loaded
                lock.unlock()
            } catch {
                populateDefaultBookmarksIfNeeded()
            }
        } else {
            populateDefaultBookmarksIfNeeded()
        }
    }

    private func populateDefaultBookmarksIfNeeded() {
        guard items.isEmpty else { return }
        let defaults: [(String, String)] = [
            ("Apple", "https://www.apple.com"),
            ("GitHub", "https://github.com"),
            ("DuckDuckGo", "https://duckduckgo.com"),
            ("Wikipedia", "https://www.wikipedia.org"),
            ("Hacker News", "https://news.ycombinator.com")
        ]
        lock.lock()
        self.items = defaults.compactMap { name, urlString in
            guard let url = URL(string: urlString) else { return nil }
            return BookmarkItem(title: name, url: url, folder: "Favorites")
        }
        lock.unlock()
        save()
    }
}
