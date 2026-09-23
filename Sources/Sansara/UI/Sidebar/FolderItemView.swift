import AppKit

/// Folder header cell in the sidebar representing a tab group.
public final class FolderItemView: NSTableCellView {

    public static let identifier = NSUserInterfaceItemIdentifier("FolderItemViewIdentifier")

    public var onToggleCollapse: (() -> Void)?
    public var onAddTab: (() -> Void)?
    public var onDoubleClick: (() -> Void)?
    public var onContextMenu: (() -> NSMenu?)?

    private let containerBox = NSBox()
    private let chevronImageView = NSImageView()
    private let folderImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let countBadge = NSTextField(labelWithString: "")
    private let addTabButton = NSButton()

    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    private var isFolderCollapsed: Bool = false

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

        containerBox.boxType = .custom
        containerBox.borderWidth = 0
        containerBox.cornerRadius = 7.0
        containerBox.fillColor = .clear
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerBox)

        // Chevron
        chevronImageView.imageScaling = .scaleProportionallyUpOrDown
        chevronImageView.contentTintColor = .secondaryLabelColor
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(chevronImageView)

        // Folder Icon
        folderImageView.imageScaling = .scaleProportionallyUpOrDown
        folderImageView.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(folderImageView)

        // Title
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(titleLabel)

        // Count Badge
        countBadge.isEditable = false
        countBadge.isSelectable = false
        countBadge.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        countBadge.textColor = .secondaryLabelColor
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(countBadge)

        // Add Tab Button (+)
        addTabButton.isBordered = false
        addTabButton.title = ""
        let plusSymbol = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add tab to folder")
        let plusConfig = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .medium)
        addTabButton.image = plusSymbol?.withSymbolConfiguration(plusConfig)
        addTabButton.contentTintColor = .secondaryLabelColor
        addTabButton.wantsLayer = true
        addTabButton.layer?.cornerRadius = 4.0
        addTabButton.target = self
        addTabButton.action = #selector(didClickAddTab)
        addTabButton.toolTip = "New Tab in Folder"
        addTabButton.isHidden = true
        addTabButton.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(addTabButton)

        NSLayoutConstraint.activate([
            containerBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            containerBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            containerBox.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            containerBox.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            chevronImageView.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 6),
            chevronImageView.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 10),
            chevronImageView.heightAnchor.constraint(equalToConstant: 10),

            folderImageView.leadingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 5),
            folderImageView.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            folderImageView.widthAnchor.constraint(equalToConstant: 15),
            folderImageView.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.leadingAnchor.constraint(equalTo: folderImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),

            countBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            countBadge.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            countBadge.trailingAnchor.constraint(lessThanOrEqualTo: addTabButton.leadingAnchor, constant: -4),

            addTabButton.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -4),
            addTabButton.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            addTabButton.widthAnchor.constraint(equalToConstant: 18),
            addTabButton.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    public func configure(with group: TabGroup, tabCount: Int) {
        self.isFolderCollapsed = group.isCollapsed
        titleLabel.stringValue = group.name.isEmpty ? "Folder" : group.name
        countBadge.stringValue = "\(tabCount)"

        // Folder Icon in group's custom color
        let folderSymbol = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: group.name)
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        folderImageView.image = folderSymbol?.withSymbolConfiguration(config)
        folderImageView.contentTintColor = group.color.nsColor

        // Chevron direction based on collapsed state
        let chevronSymbolName = group.isCollapsed ? "chevron.right" : "chevron.down"
        let chevronSymbol = NSImage(systemSymbolName: chevronSymbolName, accessibilityDescription: "Toggle Folder")
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 8.5, weight: .semibold)
        chevronImageView.image = chevronSymbol?.withSymbolConfiguration(chevronConfig)

        updateAppearance()
    }

    private func updateAppearance() {
        if isHovered {
            containerBox.fillColor = NSColor.quaternaryLabelColor
            addTabButton.isHidden = false
        } else {
            containerBox.fillColor = .clear
            addTabButton.isHidden = true
        }
    }

    @objc private func didClickAddTab() {
        onAddTab?()
    }

    public func isPointInAddButton(_ locationInWindow: NSPoint) -> Bool {
        guard !addTabButton.isHidden else { return false }
        let pointInButton = addTabButton.convert(locationInWindow, from: nil)
        return addTabButton.bounds.contains(pointInButton)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hitView = super.hitTest(point) else { return nil }
        if hitView == addTabButton || hitView.isDescendant(of: addTabButton) {
            return addTabButton
        }
        return self
    }

    public override func mouseDown(with event: NSEvent) {
        if isPointInAddButton(event.locationInWindow) {
            return
        }
        if event.clickCount == 2 {
            onToggleCollapse?()
            onDoubleClick?()
            return
        }
        onToggleCollapse?()
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
