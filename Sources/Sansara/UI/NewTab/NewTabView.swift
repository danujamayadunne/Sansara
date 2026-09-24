import AppKit

public protocol NewTabViewDelegate: AnyObject {
    func newTabView(_ view: NewTabView, didSubmitQuery query: String)
}

/// An image view that performs aspect-fill rendering anchored strictly to the top edge.
private final class WallpaperView: NSView {
    override var isFlipped: Bool { true }
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = image else { return }
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0, bounds.width > 0, bounds.height > 0 else { return }

        // Aspect fill anchored strictly to the top edge (y = 0)
        let scale = max(bounds.width / imgSize.width, bounds.height / imgSize.height)
        let scaledWidth = ceil(imgSize.width * scale)
        let scaledHeight = ceil(imgSize.height * scale)
        let originX = floor((bounds.width - scaledWidth) / 2.0)
        let originY: CGFloat = 0.0

        let targetRect = NSRect(x: originX, y: originY, width: scaledWidth, height: scaledHeight)
        image.draw(in: targetRect, from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
    }
}

/// A vertical gradient view that smoothly fades an image into a solid background color according to theme.
private final class GradientOverlayView: NSView {
    override var isFlipped: Bool { true }
    private let gradientLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer?.addSublayer(gradientLayer)
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer?.addSublayer(gradientLayer)
        updateColors()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        // Black in dark mode, white in light mode
        let baseColor = isDark ? NSColor.black : NSColor.white
        gradientLayer.colors = [
            baseColor.withAlphaComponent(0.0).cgColor,
            baseColor.withAlphaComponent(0.0).cgColor,
            baseColor.withAlphaComponent(0.30).cgColor,
            baseColor.withAlphaComponent(0.75).cgColor,
            baseColor.cgColor
        ]
        gradientLayer.locations = [0.0, 0.55, 0.72, 0.88, 1.0]
    }
}

/// New Tab page supporting Blank mode and Image mode (top artwork with theme gradient fade and centered search).
public final class NewTabView: NSView, NSTextFieldDelegate {

    public weak var delegate: NewTabViewDelegate?

    private var currentMode: NewTabPageMode = .image

    // Image mode container: Artwork at top + gradient fading to theme color at bottom
    private let wallpaperContainer = NSView()
    private let wallpaperView = WallpaperView()
    private let gradientOverlay = GradientOverlayView()

    // Centered search card (present in both Blank and Image modes)
    private let searchCard = NSBox()
    private let searchIcon = NSImageView()
    private let searchField = NSTextField()
    private let returnBadge = NSBox()
    private let returnLabel = NSTextField(labelWithString: "↵")
    private let suggestionsDropdown = SearchHistoryDropdownView()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    public override var wantsUpdateLayer: Bool {
        return true
    }

    public override func updateLayer() {
        super.updateLayer()
        updateBackgroundAndCard()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        gradientOverlay.updateColors()
        updateBackgroundAndCard()
        needsDisplay = true
    }

    private func setupViews() {
        wantsLayer = true

        // 1. Wallpaper Container (for Image mode)
        wallpaperContainer.translatesAutoresizingMaskIntoConstraints = false
        wallpaperContainer.wantsLayer = true
        addSubview(wallpaperContainer)

        wallpaperView.translatesAutoresizingMaskIntoConstraints = false
        wallpaperView.image = Self.loadWallpaperImage()
        wallpaperContainer.addSubview(wallpaperView)

        gradientOverlay.translatesAutoresizingMaskIntoConstraints = false
        wallpaperContainer.addSubview(gradientOverlay)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChangeNotification),
            name: SettingsManager.didChangeNotification,
            object: nil
        )

        // 2. Centered search card (Apple minimalist style, adapts to Image / Blank modes)
        searchCard.boxType = .custom
        searchCard.borderWidth = 1.0
        searchCard.cornerRadius = 23.0
        searchCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchCard)

        // Magnifying glass icon
        let searchSymbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        searchIcon.image = searchSymbol?.withSymbolConfiguration(config)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchIcon)

        // Return key badge
        returnBadge.boxType = .custom
        returnBadge.borderWidth = 1.0
        returnBadge.cornerRadius = 5.0
        returnBadge.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(returnBadge)

        returnLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        returnLabel.translatesAutoresizingMaskIntoConstraints = false
        returnBadge.addSubview(returnLabel)

        // Search text field
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        searchField.alignment = .left
        searchField.cell?.wraps = false
        searchField.cell?.isScrollable = true
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchSubmitted)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchField)

        // Click gesture on searchCard so clicking anywhere on the card focuses searchField
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(searchCardClicked))
        searchCard.addGestureRecognizer(clickGesture)

        // Suggestions dropdown
        suggestionsDropdown.translatesAutoresizingMaskIntoConstraints = false
        suggestionsDropdown.isHidden = true
        addSubview(suggestionsDropdown)

        suggestionsDropdown.onSelect = { [weak self] item in
            guard let self = self else { return }
            self.suggestionsDropdown.hide()
            self.delegate?.newTabView(self, didSubmitQuery: item.url.absoluteString)
        }

        NSLayoutConstraint.activate([
            // Wallpaper container pins
            wallpaperContainer.topAnchor.constraint(equalTo: topAnchor),
            wallpaperContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            wallpaperContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            wallpaperContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Wallpaper view pins
            wallpaperView.topAnchor.constraint(equalTo: wallpaperContainer.topAnchor),
            wallpaperView.leadingAnchor.constraint(equalTo: wallpaperContainer.leadingAnchor),
            wallpaperView.trailingAnchor.constraint(equalTo: wallpaperContainer.trailingAnchor),
            wallpaperView.bottomAnchor.constraint(equalTo: wallpaperContainer.bottomAnchor),

            // Gradient overlay pins
            gradientOverlay.topAnchor.constraint(equalTo: wallpaperContainer.topAnchor),
            gradientOverlay.leadingAnchor.constraint(equalTo: wallpaperContainer.leadingAnchor),
            gradientOverlay.trailingAnchor.constraint(equalTo: wallpaperContainer.trailingAnchor),
            gradientOverlay.bottomAnchor.constraint(equalTo: wallpaperContainer.bottomAnchor),

            // Search card centered
            searchCard.centerXAnchor.constraint(equalTo: centerXAnchor),
            searchCard.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            searchCard.widthAnchor.constraint(equalToConstant: 480),
            searchCard.heightAnchor.constraint(equalToConstant: 46),

            searchIcon.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),

            returnBadge.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor, constant: -14),
            returnBadge.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            returnBadge.widthAnchor.constraint(equalToConstant: 22),
            returnBadge.heightAnchor.constraint(equalToConstant: 22),

            returnLabel.centerXAnchor.constraint(equalTo: returnBadge.centerXAnchor),
            returnLabel.centerYAnchor.constraint(equalTo: returnBadge.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: returnBadge.leadingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),

            suggestionsDropdown.topAnchor.constraint(equalTo: searchCard.bottomAnchor, constant: 6),
            suggestionsDropdown.centerXAnchor.constraint(equalTo: searchCard.centerXAnchor),
            suggestionsDropdown.widthAnchor.constraint(equalTo: searchCard.widthAnchor)
        ])

        updateBackgroundAndCard()
    }

    public func setMode(_ mode: NewTabPageMode) {
        currentMode = mode
        let hasImage = (wallpaperView.image != nil)
        let isImage = (mode == .image && hasImage)
        wallpaperContainer.isHidden = !isImage
        updateBackgroundAndCard()
        needsDisplay = true
    }

    private func updateBackgroundAndCard() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let hasImage = (wallpaperView.image != nil)
        let isImage = (currentMode == .image && hasImage)
        if isImage {
            layer?.backgroundColor = (isDark ? NSColor.black : NSColor.white).cgColor
            // Make search box transparent a little if background is image
            searchCard.fillColor = isDark ? NSColor(white: 0.0, alpha: 0.65) : NSColor(white: 1.0, alpha: 0.75)
            suggestionsDropdown.setMode(isImage: true)
        } else {
            // Blank mode / no image: Clean solid background according to theme, don't transparent
            layer?.backgroundColor = ContentColors.color(for: effectiveAppearance).cgColor
            searchCard.fillColor = isDark ? .black : .white
            suggestionsDropdown.setMode(isImage: false)
        }

        // More darker border, little to no border
        searchCard.borderColor = isDark ? NSColor(white: 0.0, alpha: 0.40) : NSColor(white: 0.0, alpha: 0.08)
        searchCard.borderWidth = 0.5

        let engineName = SettingsManager.shared.searchEngine.rawValue
        let placeholderText = "Search \(engineName) or enter URL"

        if isDark {
            searchIcon.contentTintColor = NSColor(white: 1.0, alpha: 0.85)
            searchField.textColor = .white
            let placeholderAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 1.0, alpha: 0.55),
                .font: NSFont.systemFont(ofSize: 15, weight: .regular)
            ]
            searchField.placeholderAttributedString = NSAttributedString(string: placeholderText, attributes: placeholderAttrs)
            returnBadge.fillColor = NSColor(white: 1.0, alpha: 0.08)
            returnBadge.borderColor = NSColor(white: 1.0, alpha: 0.12)
            returnBadge.borderWidth = 0.5
            returnLabel.textColor = .white
        } else {
            searchIcon.contentTintColor = .secondaryLabelColor
            searchField.textColor = .labelColor
            let placeholderAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 0.0, alpha: 0.45),
                .font: NSFont.systemFont(ofSize: 15, weight: .regular)
            ]
            searchField.placeholderAttributedString = NSAttributedString(string: placeholderText, attributes: placeholderAttrs)
            returnBadge.fillColor = NSColor(white: 0.0, alpha: 0.05)
            returnBadge.borderColor = NSColor(white: 0.0, alpha: 0.08)
            returnBadge.borderWidth = 0.5
            returnLabel.textColor = .secondaryLabelColor
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Do not auto-focus so no typing indicator shows until user clicks search box
    }

    public func focus() {
        searchField.stringValue = ""
        suggestionsDropdown.hide()
        window?.makeFirstResponder(searchField)
    }

    @objc private func searchSubmitted() {
        let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestionsDropdown.hide()
        guard !text.isEmpty else { return }
        delegate?.newTabView(self, didSubmitQuery: text)
    }

    // MARK: - NSTextFieldDelegate

    public func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === searchField else { return }
        let query = searchField.stringValue
        let items = SearchSuggestionsProvider.shared.suggestions(for: query)
        if items.isEmpty {
            suggestionsDropdown.hide()
        } else {
            suggestionsDropdown.update(items: items)
        }
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField, !suggestionsDropdown.isHidden else { return false }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            suggestionsDropdown.selectNext()
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            suggestionsDropdown.selectPrevious()
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let item = suggestionsDropdown.selectedItem {
                suggestionsDropdown.hide()
                delegate?.newTabView(self, didSubmitQuery: item.url.absoluteString)
                return true
            }
            suggestionsDropdown.hide()
            return false
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            suggestionsDropdown.hide()
            return true
        }
        return false
    }

    @objc private func searchCardClicked() {
        window?.makeFirstResponder(searchField)
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(searchCard.frame, cursor: .iBeam)
    }

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if searchCard.frame.contains(point) {
            window?.makeFirstResponder(searchField)
        } else if !suggestionsDropdown.frame.contains(point) {
            suggestionsDropdown.hide()
            window?.makeFirstResponder(nil)
        }
        super.mouseDown(with: event)
    }

    // MARK: - Wallpaper Loader

    public func reloadWallpaper() {
        wallpaperView.image = Self.loadWallpaperImage()
    }

    @objc private func settingsDidChangeNotification() {
        reloadWallpaper()
        setMode(SettingsManager.shared.newTabPageMode)
    }

    private static func loadWallpaperImage() -> NSImage? {
        if let customPath = SettingsManager.shared.customWallpaperPath,
           FileManager.default.fileExists(atPath: customPath),
           let img = NSImage(contentsOfFile: customPath) {
            return img
        }
        return nil
    }
}

