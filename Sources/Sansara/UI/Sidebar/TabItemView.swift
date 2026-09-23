import AppKit

/// Clean, all-white Arc-style tab cell view.
public final class TabItemView: NSTableCellView {

    public static let identifier = NSUserInterfaceItemIdentifier("TabItemViewIdentifier")

    public var onClose: (() -> Void)?

    private let cardBackground = NSBox()
    private let faviconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    private var isTabSelected: Bool = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true

        // Tab item background card
        cardBackground.boxType = .custom
        cardBackground.borderWidth = 0
        cardBackground.cornerRadius = 8.0
        cardBackground.fillColor = .clear
        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardBackground)

        // Favicon
        faviconImageView.imageScaling = .scaleProportionallyUpOrDown
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(faviconImageView)

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.48, alpha: 1.0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(titleLabel)

        // Close button
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare
        closeButton.title = ""
        let closeSymbol = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")
        let config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .semibold)
        closeButton.image = closeSymbol?.withSymbolConfiguration(config)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 9.0
        closeButton.target = self
        closeButton.action = #selector(didClickClose)
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(closeButton)

        NSLayoutConstraint.activate([
            cardBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            cardBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            cardBackground.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            cardBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            faviconImageView.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: 8),
            faviconImageView.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 14),
            faviconImageView.heightAnchor.constraint(equalToConstant: 14),

            closeButton.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            titleLabel.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor)
        ])
    }

    public func configure(with tab: BrowserTab, isSelected: Bool) {
        self.isTabSelected = isSelected
        titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
        faviconImageView.image = tab.favicon
        updateAppearance()
    }

    private func updateAppearance() {
        if isTabSelected {
            // Selected active tab: soft clean light card
            cardBackground.fillColor = NSColor(white: 0.95, alpha: 1.0)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = .labelColor
            closeButton.isHidden = !isHovered
        } else if isHovered {
            cardBackground.fillColor = NSColor(white: 0.97, alpha: 1.0)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = NSColor(white: 0.20, alpha: 1.0)
            closeButton.isHidden = false
        } else {
            cardBackground.fillColor = .clear
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = NSColor(white: 0.48, alpha: 1.0)
            closeButton.isHidden = true
        }
    }

    @objc private func didClickClose() {
        onClose?()
    }

    // MARK: - Hover Tracking

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateAppearance()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateAppearance()
    }
}
