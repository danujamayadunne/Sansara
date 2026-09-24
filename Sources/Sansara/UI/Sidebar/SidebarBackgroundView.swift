import AppKit

/// Defines colors for the Arc-style sidebar across macOS appearances.
public enum SidebarColors {
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

    /// Resolves the sidebar background color for a given NSAppearance.
    public static func color(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return matteBlackBackground
        } else {
            return lightBackground
        }
    }
}

/// Opaque background view for the sidebar providing pure white in light mode
/// and matte black (#141414) in dark mode.
public final class SidebarBackgroundView: NSView {

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateBackgroundColor()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        updateBackgroundColor()
    }

    public override var isOpaque: Bool {
        return true
    }

    public override var wantsUpdateLayer: Bool {
        return true
    }

    public override func updateLayer() {
        super.updateLayer()
        updateBackgroundColor()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
        needsDisplay = true
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackgroundColor()
    }

    public override var appearance: NSAppearance? {
        didSet {
            super.appearance = appearance
            updateBackgroundColor()
            needsDisplay = true
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        let currentApp = appearance ?? effectiveAppearance
        SidebarColors.color(for: currentApp).setFill()
        dirtyRect.fill()
    }

    private func updateBackgroundColor() {
        let currentApp = appearance ?? effectiveAppearance
        layer?.backgroundColor = SidebarColors.color(for: currentApp).cgColor
    }
}
