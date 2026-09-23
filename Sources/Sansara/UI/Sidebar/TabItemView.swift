import AppKit

/// Clean Arc-style tab cell view, supporting nested folder layout.
public final class TabItemView: NSTableCellView {

    public static let identifier = NSUserInterfaceItemIdentifier("TabItemViewIdentifier")

    public var onClose: (() -> Void)?
    public var onDoubleClick: (() -> Void)?
    public var onContextMenu: (() -> NSMenu?)?
    public var onRename: ((String) -> Void)?

    public private(set) var isEditing: Bool = false
    private weak var tab: BrowserTab?

    private let cardBackground = NSBox()
    private let groupDotView = NSView()
    private let faviconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let inlineEditor = InlineRenameTextField()
    private let closeButton = NSButton()

    private var cardLeadingConstraint: NSLayoutConstraint!
    private var faviconLeadingToCard: NSLayoutConstraint!
    private var faviconLeadingToDot: NSLayoutConstraint!

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

        // Nested folder color dot indicator
        groupDotView.wantsLayer = true
        groupDotView.layer?.cornerRadius = 2.5
        groupDotView.isHidden = true
        groupDotView.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(groupDotView)

        // Favicon
        faviconImageView.imageScaling = .scaleProportionallyUpOrDown
        faviconImageView.wantsLayer = true
        faviconImageView.layer?.cornerRadius = 2.0
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(faviconImageView)

        // Title
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(titleLabel)

        // Inline Editor
        inlineEditor.isHidden = true
        inlineEditor.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        inlineEditor.translatesAutoresizingMaskIntoConstraints = false
        inlineEditor.onCommit = { [weak self] newTitle in
            self?.finishEditing(newTitle: newTitle)
        }
        inlineEditor.onCancel = { [weak self] in
            self?.cancelEditing()
        }
        cardBackground.addSubview(inlineEditor)

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

        cardLeadingConstraint = cardBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6)
        faviconLeadingToCard = faviconImageView.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: 8)
        faviconLeadingToDot = faviconImageView.leadingAnchor.constraint(equalTo: groupDotView.trailingAnchor, constant: 6)

        NSLayoutConstraint.activate([
            cardLeadingConstraint,
            cardBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            cardBackground.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            cardBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            groupDotView.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: 8),
            groupDotView.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            groupDotView.widthAnchor.constraint(equalToConstant: 5),
            groupDotView.heightAnchor.constraint(equalToConstant: 5),

            faviconLeadingToCard,
            faviconImageView.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 14),
            faviconImageView.heightAnchor.constraint(equalToConstant: 14),

            closeButton.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            titleLabel.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),

            inlineEditor.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 6),
            inlineEditor.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -6),
            inlineEditor.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
        ])
    }

    public func isPointInCloseButton(_ locationInWindow: NSPoint) -> Bool {
        guard !closeButton.isHidden else { return false }
        let pointInButton = closeButton.convert(locationInWindow, from: nil)
        return closeButton.bounds.contains(pointInButton)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hitView = super.hitTest(point) else { return nil }
        if hitView == closeButton || hitView.isDescendant(of: closeButton) {
            return closeButton
        }
        if isEditing {
            if hitView == inlineEditor || hitView.isDescendant(of: inlineEditor) {
                return hitView
            }
        }
        return self
    }

    public override func mouseDown(with event: NSEvent) {
        if isPointInCloseButton(event.locationInWindow) {
            return
        }
        if isEditing {
            return
        }
        if event.clickCount == 2 {
            startEditing()
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        return onContextMenu?()
    }

    public override func rightMouseDown(with event: NSEvent) {
        if let menu = onContextMenu?() ?? menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    public func configure(with tab: BrowserTab, isSelected: Bool, isInsideGroup: Bool = false, groupColor: TabGroupColor? = nil) {
        self.tab = tab
        self.isTabSelected = isSelected
        if !isEditing {
            titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
        }
        faviconImageView.image = tab.favicon

        if isInsideGroup, let color = groupColor {
            cardLeadingConstraint.constant = 18
            groupDotView.isHidden = false
            groupDotView.layer?.backgroundColor = color.nsColor.cgColor
            faviconLeadingToCard.isActive = false
            faviconLeadingToDot.isActive = true
        } else {
            cardLeadingConstraint.constant = 6
            groupDotView.isHidden = true
            faviconLeadingToDot.isActive = false
            faviconLeadingToCard.isActive = true
        }

        updateAppearance()
    }

    // MARK: - Inline Renaming

    public func startEditing() {
        guard !isEditing, let tab = tab else { return }
        isEditing = true
        titleLabel.isHidden = true
        closeButton.isHidden = true
        inlineEditor.beginEditing(initialText: tab.title)
    }

    public func finishEditing(newTitle: String) {
        guard isEditing else { return }
        isEditing = false
        inlineEditor.isHidden = true
        titleLabel.isHidden = false
        closeButton.isHidden = !isHovered

        if let tab = tab {
            tab.rename(to: newTitle)
            titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
            onRename?(newTitle)
        }
        updateAppearance()
        window?.makeFirstResponder(superview)
    }

    public func cancelEditing() {
        guard isEditing else { return }
        isEditing = false
        inlineEditor.isHidden = true
        titleLabel.isHidden = false
        closeButton.isHidden = !isHovered
        updateAppearance()
        window?.makeFirstResponder(superview)
    }

    private static let selectedTabFillColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            return NSColor.selectedControlColor.withAlphaComponent(0.20)
        } else {
            return NSColor.selectedControlColor.withAlphaComponent(0.35)
        }
    }

    private func updateAppearance() {
        if isTabSelected {
            cardBackground.fillColor = TabItemView.selectedTabFillColor
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = .labelColor
            closeButton.isHidden = isEditing || !isHovered
        } else if isHovered {
            cardBackground.fillColor = NSColor.quaternaryLabelColor
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = .labelColor
            closeButton.isHidden = isEditing ? true : false
        } else {
            cardBackground.fillColor = .clear
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = .secondaryLabelColor
            closeButton.isHidden = true
        }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
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
