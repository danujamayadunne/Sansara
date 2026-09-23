import AppKit

/// Defines colors for the content canvas side across macOS appearances.
public enum ContentColors {
    /// Pure white in light appearance (#FFFFFF)
    public static let lightBackground: NSColor = .white

    /// Matte black in dark appearance (#141414)
    public static let matteBlackBackground: NSColor = NSColor(
        srgbRed: 20.0 / 255.0,
        green: 20.0 / 255.0,
        blue: 20.0 / 255.0,
        alpha: 1.0
    )

    /// Dynamic NSColor resolving to pure white in light mode and matte black in dark mode.
    public static let dynamicBackground = NSColor(name: nil) { appearance in
        return color(for: appearance)
    }

    /// Resolves the content background color for a given NSAppearance.
    public static func color(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return matteBlackBackground
        } else {
            return lightBackground
        }
    }
}
