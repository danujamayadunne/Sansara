import Foundation
import AppKit

public enum SearchEngine: String, CaseIterable, Codable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"
    case brave = "Brave"
    case ecosia = "Ecosia"

    public var searchEndpoint: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q="
        case .duckDuckGo:
            return "https://duckduckgo.com/?q="
        case .bing:
            return "https://www.bing.com/search?q="
        case .brave:
            return "https://search.brave.com/search?q="
        case .ecosia:
            return "https://www.ecosia.org/search?q="
        }
    }

    public func searchURL(for query: String) -> URL {
        let queryAllowed = CharacterSet.urlQueryAllowed
        let encoded = query.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? query
        return URL(string: searchEndpoint + encoded) ?? URL(string: "https://www.google.com")!
    }
}

public enum AppearanceMode: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

public enum NewTabPageMode: String, CaseIterable, Codable {
    case minimal = "Minimal Search"
    case blank = "Blank Page"
}

public final class SettingsManager: NSObject {

    public static let shared = SettingsManager()

    public static let didChangeNotification = Notification.Name("SansaraSettingsDidChangeNotification")

    private let defaults: UserDefaults

    private enum Keys {
        static let searchEngine = "sansara.settings.searchEngine"
        static let appearanceMode = "sansara.settings.appearanceMode"
        static let newTabPageMode = "sansara.settings.newTabPageMode"
        static let isContentBlockerEnabled = "sansara.settings.isContentBlockerEnabled"
        static let tabNapEnabled = "sansara.settings.tabNapEnabled"
        static let tabNapThreshold = "sansara.settings.tabNapThreshold"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    public var searchEngine: SearchEngine {
        get {
            guard let raw = defaults.string(forKey: Keys.searchEngine),
                  let engine = SearchEngine(rawValue: raw) else {
                return .google
            }
            return engine
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.searchEngine)
            notifyChange()
        }
    }

    public var appearanceMode: AppearanceMode {
        get {
            guard let raw = defaults.string(forKey: Keys.appearanceMode),
                  let mode = AppearanceMode(rawValue: raw) else {
                return .system
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appearanceMode)
            applyAppearance()
            notifyChange()
        }
    }

    public var newTabPageMode: NewTabPageMode {
        get {
            guard let raw = defaults.string(forKey: Keys.newTabPageMode),
                  let mode = NewTabPageMode(rawValue: raw) else {
                return .minimal
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.newTabPageMode)
            notifyChange()
        }
    }

    public var isContentBlockerEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isContentBlockerEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.isContentBlockerEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isContentBlockerEnabled)
            notifyChange()
        }
    }

    public var tabNapEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.tabNapEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.tabNapEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.tabNapEnabled)
            notifyChange()
        }
    }

    public var tabNapThreshold: Int {
        get {
            let val = defaults.integer(forKey: Keys.tabNapThreshold)
            return val > 0 ? val : 15
        }
        set {
            defaults.set(newValue, forKey: Keys.tabNapThreshold)
            notifyChange()
        }
    }

    public func applyAppearance() {
        NSApp?.appearance = appearanceMode.nsAppearance
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: SettingsManager.didChangeNotification, object: self)
    }

    public func resetToDefaults() {
        searchEngine = .google
        appearanceMode = .system
        newTabPageMode = .minimal
        isContentBlockerEnabled = true
        tabNapEnabled = true
        tabNapThreshold = 15
    }
}
