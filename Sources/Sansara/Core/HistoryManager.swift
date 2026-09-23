import Foundation

public struct HistoryItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public var title: String
    public let visitDate: Date

    public init(id: UUID = UUID(), url: URL, title: String, visitDate: Date = Date()) {
        self.id = id
        self.url = url
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = cleanTitle.isEmpty ? (url.host ?? url.absoluteString) : cleanTitle
        self.visitDate = visitDate
    }
}

public final class HistoryManager: NSObject {

    public static let shared = HistoryManager()

    public static let didUpdateNotification = Notification.Name("SansaraHistoryDidUpdateNotification")

    private var items: [HistoryItem] = []
    private let lock = NSLock()
    private let fileURL: URL?

    public init(fileURL: URL? = HistoryManager.defaultStorageURL()) {
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
        return dir.appendingPathComponent("history.json")
    }

    // MARK: - Core Operations

    @discardableResult
    public func addVisit(url: URL, title: String) -> HistoryItem? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        lock.lock()
        defer {
            lock.unlock()
            save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HistoryManager.didUpdateNotification, object: self)
            }
        }

        // Avoid rapid duplicate entries for same URL within 5 seconds
        if let first = items.first, first.url == url, abs(first.visitDate.timeIntervalSinceNow) < 5.0 {
            if !title.isEmpty && title != "Loading…" && title != "New Tab" && first.title != title {
                items[0] = HistoryItem(id: first.id, url: first.url, title: title, visitDate: first.visitDate)
            }
            return items.first
        }

        let item = HistoryItem(url: url, title: title)
        items.insert(item, at: 0)

        // Maintain maximum 3000 history entries
        if items.count > 3000 {
            items.removeLast(items.count - 3000)
        }

        return item
    }

    public func updateTitle(for url: URL, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != "Loading…", clean != "New Tab" else { return }

        lock.lock()
        var updated = false
        for (index, item) in items.enumerated() where item.url == url {
            if item.title != clean {
                items[index] = HistoryItem(id: item.id, url: item.url, title: clean, visitDate: item.visitDate)
                updated = true
            }
        }
        lock.unlock()

        if updated {
            save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HistoryManager.didUpdateNotification, object: self)
            }
        }
    }

    public func deleteItem(id: UUID) {
        lock.lock()
        items.removeAll(where: { $0.id == id })
        lock.unlock()
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: HistoryManager.didUpdateNotification, object: self)
        }
    }

    public func clearAll() {
        lock.lock()
        items.removeAll()
        lock.unlock()
        save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: HistoryManager.didUpdateNotification, object: self)
        }
    }

    public func allHistory() -> [HistoryItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    public func recentHistory(limit: Int = 10) -> [HistoryItem] {
        lock.lock()
        defer { lock.unlock() }
        return Array(items.prefix(limit))
    }

    public func search(query: String) -> [HistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        defer { lock.unlock() }
        guard !trimmed.isEmpty else { return items }

        return items.filter { item in
            item.title.lowercased().contains(trimmed) ||
            item.url.absoluteString.lowercased().contains(trimmed)
        }
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
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([HistoryItem].self, from: data)
            lock.lock()
            self.items = loaded
            lock.unlock()
        } catch {
            // Fallback gracefully on corrupt or missing file
        }
    }
}
