import AppKit

/// Defines colors for the horizontal tab stripe chips across macOS appearances.
public enum TabStripeColors {
    /// Active tab background in light appearance: crisp pure white card (#FFFFFF)
    public static let lightActiveBackground: NSColor = .controlBackgroundColor

    /// Active tab background in dark appearance: elevated luminous card (#FFFFFF 14%)
    public static let darkActiveBackground: NSColor = NSColor(white: 1.0, alpha: 0.14)

    /// Active tab border in light appearance (#000000 8%)
    public static let lightActiveBorder: NSColor = NSColor(white: 0.0, alpha: 0.08)

    /// Active tab border in dark appearance (#000000 35% or subtle dark)
    public static let darkActiveBorder: NSColor = NSColor(white: 0.0, alpha: 0.35)

    /// Inactive tab background in light appearance: subtle little gray (#000000 6.5%)
    public static let lightInactiveBackground: NSColor = NSColor(white: 0.0, alpha: 0.065)

    /// Inactive tab background in dark appearance: subtle elevated dark gray (#FFFFFF 8%)
    public static let darkInactiveBackground: NSColor = NSColor(white: 1.0, alpha: 0.08)

    /// Inactive tab hover background in light appearance (#000000 9%)
    public static let lightHoverBackground: NSColor = NSColor(white: 0.0, alpha: 0.09)

    /// Inactive tab hover background in dark appearance (#FFFFFF 12%)
    public static let darkHoverBackground: NSColor = NSColor(white: 1.0, alpha: 0.12)

    /// Dynamic NSColor resolving to pure white in light mode and elevated luminous dark in dark mode.
    public static let dynamicActiveBackground = NSColor(name: nil) { appearance in
        return activeBackgroundColor(for: appearance)
    }

    /// Dynamic NSColor resolving to subtle border defining the active card in both modes.
    public static let dynamicActiveBorder = NSColor(name: nil) { appearance in
        return activeBorderColor(for: appearance)
    }

    /// Dynamic NSColor resolving to subtle little gray in light mode and subtle elevated dark gray in dark mode.
    public static let dynamicInactiveBackground = NSColor(name: nil) { appearance in
        return inactiveBackgroundColor(for: appearance)
    }

    /// Dynamic NSColor resolving to hover gray in light mode and hover dark gray in dark mode.
    public static let dynamicHoverBackground = NSColor(name: nil) { appearance in
        return hoverBackgroundColor(for: appearance)
    }

    /// Resolves the active tab background color for a given NSAppearance.
    public static func activeBackgroundColor(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return darkActiveBackground
        } else {
            return lightActiveBackground
        }
    }

    /// Resolves the active tab border color for a given NSAppearance.
    public static func activeBorderColor(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return darkActiveBorder
        } else {
            return lightActiveBorder
        }
    }

    /// Resolves the inactive tab background color for a given NSAppearance.
    public static func inactiveBackgroundColor(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return darkInactiveBackground
        } else {
            return lightInactiveBackground
        }
    }

    /// Resolves the hover tab background color for a given NSAppearance.
    public static func hoverBackgroundColor(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return darkHoverBackground
        } else {
            return lightHoverBackground
        }
    }
}
