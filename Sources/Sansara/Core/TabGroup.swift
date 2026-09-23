import AppKit

/// Preset color palette for tab groups and folders
public enum TabGroupColor: String, CaseIterable, Codable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case gray = "Gray"

    public var hex: String {
        switch self {
        case .blue: return "#007AFF"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        case .gray: return "#8E8E93"
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .blue: return NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        case .purple: return NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)
        case .pink: return NSColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0)
        case .red: return NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        case .orange: return NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case .yellow: return NSColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0)
        case .green: return NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        case .gray: return NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
        }
    }

    /// Generates a circular color swatch icon for menus and buttons
    public func circleImage(size: CGFloat = 12) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        nsColor.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size))
        path.fill()
        image.unlockFocus()
        return image
    }
}

/// Represents a folder or group of tabs with a custom name, color, and collapsed state.
public final class TabGroup: NSObject {
    public let id: UUID
    public var name: String
    public var color: TabGroupColor
    public var isCollapsed: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        color: TabGroupColor = .blue,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.isCollapsed = isCollapsed
        super.init()
    }
}
