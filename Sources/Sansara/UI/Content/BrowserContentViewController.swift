import AppKit

// MARK: - Stripe Group View (Horizontal Group Pill / Folder Badge)

private final class StripeGroupView: NSView {

    var onToggleCollapse: (() -> Void)?
    var onContextMenu: (() -> NSMenu?)?
    var onDoubleClick: (() -> Void)?

    private(set) var group: TabGroup
    private(set) var tabCount: Int

    var isDropTarget: Bool = false {
        didSet {
            if oldValue != isDropTarget {
                updateAppearance()
            }
        }
    }

    private let containerBox = NSBox()
    private let folderImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var desiredWidth: CGFloat {
        let labelWidth = titleLabel.intrinsicContentSize.width
        return max(52, min(240, ceil(labelWidth + 33)))
    }

    init(group: TabGroup, tabCount: Int) {
        self.group = group
        self.tabCount = tabCount
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true

        containerBox.boxType = .custom
        containerBox.cornerRadius = 6.0
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerBox)

        // Folder Icon in group's custom color
        folderImageView.imageScaling = .scaleProportionallyUpOrDown
        let folderSymbol = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: group.name)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        folderImageView.image = folderSymbol?.withSymbolConfiguration(config)
        folderImageView.contentTintColor = group.color.nsColor
        folderImageView.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(folderImageView)

        // Title Label - Clean native name, no brackets or count
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.alignment = .left
        titleLabel.stringValue = group.name.isEmpty ? "Folder" : group.name
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            containerBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerBox.topAnchor.constraint(equalTo: topAnchor),
            containerBox.bottomAnchor.constraint(equalTo: bottomAnchor),

            folderImageView.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 7),
            folderImageView.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            folderImageView.widthAnchor.constraint(equalToConstant: 13),
            folderImageView.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: folderImageView.trailingAnchor, constant: 5),
            titleLabel.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -7),
            titleLabel.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor)
        ])

        toolTip = "\(group.name) (Click to toggle, double-click to rename)"
        updateAppearance()
    }

    func configure(group: TabGroup, tabCount: Int) {
        self.group = group
        self.tabCount = tabCount
        folderImageView.contentTintColor = group.color.nsColor
        titleLabel.stringValue = group.name.isEmpty ? "Folder" : group.name
        toolTip = "\(group.name) (Click to toggle, double-click to rename)"
        updateAppearance()
    }

    private func updateAppearance() {
        let baseColor = group.color.nsColor
        if isDropTarget {
            containerBox.fillColor = baseColor.withAlphaComponent(0.35)
            containerBox.borderColor = baseColor
            containerBox.borderWidth = 1.5
        } else if isHovered {
            containerBox.fillColor = baseColor.withAlphaComponent(0.24)
            containerBox.borderColor = baseColor.withAlphaComponent(0.60)
            containerBox.borderWidth = 1.0
        } else {
            containerBox.fillColor = baseColor.withAlphaComponent(0.14)
            containerBox.borderColor = baseColor.withAlphaComponent(0.35)
            containerBox.borderWidth = 1.0
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onToggleCollapse?() // Revert the collapse toggle caused by 1st click
            onDoubleClick?()
            return
        }
        onToggleCollapse?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return onContextMenu?()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = onContextMenu?() ?? self.menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }
}

// MARK: - Stripe Tab View (polished, Apple-quality tab chip for the horizontal strip)

private final class StripeTabView: NSView, NSDraggingSource {

    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onContextMenu: (() -> NSMenu?)?
    var onDoubleClick: (() -> Void)?



    private(set) var tab: BrowserTab?
    private(set) var isEditing: Bool = false
    private(set) var isImageMode: Bool = false

    private let cardBackground = NSBox()
    private let topAccentBar = NSBox()
    private let centerStack = NSStackView()
    private let faviconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let inlineEditor = InlineRenameTextField()
    private let closeButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isTabSelected = false
    private(set) var groupColor: TabGroupColor?
    private var dragStartPoint: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Clean tab background card
        cardBackground.boxType = .custom
        cardBackground.borderWidth = 0
        cardBackground.cornerRadius = 7.0
        cardBackground.fillColor = .clear
        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardBackground)

        // Top accent bar for group color
        topAccentBar.boxType = .custom
        topAccentBar.borderWidth = 0
        topAccentBar.cornerRadius = 1.0
        topAccentBar.isHidden = true
        topAccentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topAccentBar)

        // Favicon (16x16, crisp)
        faviconView.imageScaling = .scaleProportionallyUpOrDown
        faviconView.wantsLayer = true
        faviconView.layer?.cornerRadius = 2.0
        faviconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        faviconView.setContentHuggingPriority(.required, for: .horizontal)
        faviconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.3, alpha: 1.0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.alignment = .center
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Inline Editor
        inlineEditor.isHidden = true
        inlineEditor.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        inlineEditor.alignment = .center
        inlineEditor.minCharacterWidth = 9
        inlineEditor.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        inlineEditor.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inlineEditor.translatesAutoresizingMaskIntoConstraints = false
        inlineEditor.onCommit = { [weak self] newTitle in
            self?.finishEditing(newTitle: newTitle)
        }
        inlineEditor.onCancel = { [weak self] in
            self?.cancelEditing()
        }

        // Centered stack holding favicon and title
        centerStack.orientation = .horizontal
        centerStack.spacing = 6
        centerStack.alignment = .centerY
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(faviconView)
        centerStack.addArrangedSubview(titleLabel)
        centerStack.addArrangedSubview(inlineEditor)
        addSubview(centerStack)

        // Close button (hidden by default, shown on hover)
        closeButton.isBordered = false
        closeButton.title = ""
        let closeSymbol = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")
        let config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .semibold)
        closeButton.image = closeSymbol?.withSymbolConfiguration(config)
        closeButton.contentTintColor = NSColor(white: 0.40, alpha: 1.0)
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 9.0
        closeButton.target = self
        closeButton.action = #selector(didClose)
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            cardBackground.topAnchor.constraint(equalTo: topAnchor),
            cardBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            topAccentBar.topAnchor.constraint(equalTo: topAnchor),
            topAccentBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topAccentBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            topAccentBar.heightAnchor.constraint(equalToConstant: 2.5),

            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            faviconView.widthAnchor.constraint(equalToConstant: 16),
            faviconView.heightAnchor.constraint(equalToConstant: 16),

            inlineEditor.widthAnchor.constraint(greaterThanOrEqualToConstant: 85),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let localPoint = convert(point, from: superview)
        if !closeButton.isHidden && closeButton.frame.contains(localPoint) {
            return closeButton
        }
        if isEditing {
            guard let editorSuperview = inlineEditor.superview else { return self }
            let ptInEditorSuperview = editorSuperview.convert(point, from: superview)
            if let target = inlineEditor.hitTest(ptInEditorSuperview) {
                return target
            }
        }
        return self
    }

    func configure(tab: BrowserTab, isSelected: Bool, groupColor: TabGroupColor? = nil, isImageMode: Bool = false) {
        self.tab = tab
        self.isTabSelected = isSelected
        self.groupColor = groupColor
        self.isImageMode = isImageMode

        let size = NSSize(width: 16, height: 16)
        let scaled = NSImage(size: size, flipped: false) { rect in
            tab.favicon.draw(in: rect)
            return true
        }
        faviconView.image = scaled
        if !isEditing {
            titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
        }
        toolTip = "\(tab.title) (Double-click to rename, drag to reorder)"

        if let groupColor = groupColor {
            topAccentBar.isHidden = false
            topAccentBar.fillColor = groupColor.nsColor
        } else {
            topAccentBar.isHidden = true
        }

        updateAppearance()
    }

    // MARK: - Inline Renaming

    func startEditing() {
        guard !isEditing, let tab = tab else { return }
        isEditing = true
        titleLabel.isHidden = true
        closeButton.isHidden = true
        inlineEditor.beginEditing(initialText: tab.title)
    }

    func finishEditing(newTitle: String) {
        guard isEditing else { return }
        isEditing = false
        inlineEditor.isHidden = true
        titleLabel.isHidden = false
        closeButton.isHidden = !isHovered

        if let tab = tab {
            tab.rename(to: newTitle)
            titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
            toolTip = "\(tab.title) (Double-click to rename, drag to reorder)"
        }
        updateAppearance()
        window?.makeFirstResponder(superview)
    }

    func cancelEditing() {
        guard isEditing else { return }
        isEditing = false
        inlineEditor.isHidden = true
        titleLabel.isHidden = false
        closeButton.isHidden = !isHovered
        updateAppearance()
        window?.makeFirstResponder(superview)
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isTabSelected {
            cardBackground.fillColor = isImageMode
                ? (isDark ? NSColor(white: 1.0, alpha: 0.22) : NSColor.controlBackgroundColor.withAlphaComponent(0.92))
                : TabStripeColors.dynamicActiveBackground
            cardBackground.borderColor = isDark ? NSColor(white: 0.0, alpha: 0.35) : TabStripeColors.dynamicActiveBorder
            cardBackground.borderWidth = 0.5
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            titleLabel.textColor = isDark ? .white : .labelColor
        } else if isHovered {
            cardBackground.fillColor = isImageMode
                ? (isDark ? NSColor(white: 0.0, alpha: 0.42) : NSColor(white: 0.0, alpha: 0.12))
                : TabStripeColors.dynamicHoverBackground
            cardBackground.borderColor = .clear
            cardBackground.borderWidth = 0
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
            titleLabel.textColor = isDark ? .white : .labelColor
        } else {
            // Unused / inactive tab
            cardBackground.fillColor = isImageMode
                ? (isDark ? NSColor(white: 0.0, alpha: 0.28) : NSColor(white: 0.0, alpha: 0.08))
                : TabStripeColors.dynamicInactiveBackground
            cardBackground.borderColor = isImageMode
                ? (isDark ? NSColor(white: 0.0, alpha: 0.35) : NSColor(white: 0.0, alpha: 0.08))
                : .clear
            cardBackground.borderWidth = isImageMode ? 0.5 : 0
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
            titleLabel.textColor = isImageMode
                ? (isDark ? NSColor(white: 1.0, alpha: 0.85) : .labelColor)
                : .secondaryLabelColor
        }
        closeButton.isHidden = isEditing || !isHovered
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    @objc private func didClose() {
        onClose?()
    }

    override func mouseDown(with event: NSEvent) {
        if isEditing {
            return
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        if !closeButton.isHidden && closeButton.frame.contains(localPoint) {
            return
        }
        if event.clickCount == 2 {
            dragStartPoint = nil
            startEditing()
            onDoubleClick?()
            return
        }
        dragStartPoint = event.locationInWindow
        onSelect?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartPoint, let tab = tab else { return }
        let current = event.locationInWindow
        let dist = hypot(current.x - start.x, current.y - start.y)
        guard dist > 4 else { return }
        dragStartPoint = nil

        let pbItem = NSPasteboardItem()
        pbItem.setString(tab.id.uuidString, forType: NSPasteboard.PasteboardType("com.sansara.browser.tab"))
        pbItem.setString(tab.id.uuidString, forType: .string)

        let dragItem = NSDraggingItem(pasteboardWriter: pbItem)
        let image = NSImage(size: bounds.size)
        if bounds.width > 0, bounds.height > 0, let rep = bitmapImageRepForCachingDisplay(in: bounds) {
            cacheDisplay(in: bounds, to: rep)
            image.addRepresentation(rep)
        }
        dragItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    override func mouseUp(with event: NSEvent) {
        dragStartPoint = nil
        super.mouseUp(with: event)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragStartPoint = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return onContextMenu?()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = onContextMenu?() ?? self.menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }
}

// MARK: - Tab Strip View (manages dynamic non-overflowing tab layout like Chrome / Safari)

private final class TabStripView: NSView {

    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onReload: (() -> Void)?
    var onNewTab: (() -> Void)?
    var onContextMenu: (() -> NSMenu?)?
    var onDropTab: ((_ draggedTabId: UUID, _ targetView: NSView?, _ dropAfter: Bool) -> Void)?

    enum ItemDescriptor: Equatable {
        case group(id: UUID, isCollapsed: Bool)
        case tab(id: UUID)
    }

    var currentItemDescriptors: [ItemDescriptor] {
        return itemViews.compactMap { view in
            if let groupView = view as? StripeGroupView {
                return .group(id: groupView.group.id, isCollapsed: groupView.group.isCollapsed)
            } else if let tabView = view as? StripeTabView, let tab = tabView.tab {
                return .tab(id: tab.id)
            }
            return nil
        }
    }

    private(set) var itemViews: [NSView] = []
    let backButton = HoverIconButton()
    let forwardButton = HoverIconButton()
    let reloadButton = HoverIconButton()
    let plusButton = HoverIconButton()
    private let bottomBorder = NSBox()
    private let dropIndicatorLine = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var wantsUpdateLayer: Bool {
        return true
    }

    private var isImageMode: Bool = false

    func setImageModeBackground(_ isImageMode: Bool) {
        self.isImageMode = isImageMode
        updateBackground()
    }

    private func updateBackground() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isImageMode {
            // Add a little more gray in tab stripe so unused tabs can be seen clearly over bright artwork
            layer?.backgroundColor = isDark
                ? NSColor(white: 0.08, alpha: 0.55).cgColor
                : NSColor(white: 0.20, alpha: 0.20).cgColor
            bottomBorder.fillColor = isDark
                ? NSColor(white: 0.0, alpha: 0.35)
                : NSColor(white: 0.0, alpha: 0.12)
            bottomBorder.isHidden = false
        } else {
            layer?.backgroundColor = ContentColors.color(for: effectiveAppearance).cgColor
            bottomBorder.fillColor = .separatorColor
            bottomBorder.isHidden = false
        }
    }

    override func updateLayer() {
        super.updateLayer()
        updateBackground()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
        needsDisplay = true
    }

    private func setup() {
        wantsLayer = true
        updateBackground()

        bottomBorder.boxType = .custom
        bottomBorder.borderWidth = 0
        bottomBorder.fillColor = .separatorColor
        addSubview(bottomBorder)

        dropIndicatorLine.boxType = .custom
        dropIndicatorLine.borderWidth = 0
        dropIndicatorLine.cornerRadius = 1.25
        dropIndicatorLine.fillColor = .controlAccentColor
        dropIndicatorLine.isHidden = true
        addSubview(dropIndicatorLine)

        let navConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)

        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back (⌘[)")?.withSymbolConfiguration(navConfig)
        backButton.contentTintColor = .secondaryLabelColor
        backButton.toolTip = "Back (⌘[)"
        backButton.target = self
        backButton.action = #selector(didClickBack)
        addSubview(backButton)

        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward (⌘])")?.withSymbolConfiguration(navConfig)
        forwardButton.contentTintColor = .secondaryLabelColor
        forwardButton.toolTip = "Forward (⌘])"
        forwardButton.target = self
        forwardButton.action = #selector(didClickForward)
        addSubview(forwardButton)

        reloadButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload (⌘R)")?.withSymbolConfiguration(navConfig)
        reloadButton.contentTintColor = .secondaryLabelColor
        reloadButton.toolTip = "Reload (⌘R)"
        reloadButton.target = self
        reloadButton.action = #selector(didClickReload)
        addSubview(reloadButton)

        let plusImage = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        plusButton.image = plusImage?.withSymbolConfiguration(navConfig)
        plusButton.contentTintColor = .secondaryLabelColor
        plusButton.target = self
        plusButton.action = #selector(didClickPlus)
        plusButton.toolTip = "New Tab (⌘T)"
        addSubview(plusButton)

        registerForDraggedTypes([
            NSPasteboard.PasteboardType("com.sansara.browser.tab"),
            .string
        ])
    }

    @objc private func didClickBack() {
        onBack?()
    }

    @objc private func didClickForward() {
        onForward?()
    }

    @objc private func didClickReload() {
        onReload?()
    }

    @objc private func didClickPlus() {
        onNewTab?()
    }

    func updateNavButtons(canGoBack: Bool, canGoForward: Bool) {
        backButton.isEnabled = canGoBack
        backButton.contentTintColor = canGoBack ? .secondaryLabelColor : .tertiaryLabelColor
        forwardButton.isEnabled = canGoForward
        forwardButton.contentTintColor = canGoForward ? .secondaryLabelColor : .tertiaryLabelColor
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return onContextMenu?()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = onContextMenu?() ?? self.menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    func setItems(_ views: [NSView]) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews = views
        for v in views {
            addSubview(v)
        }
        bringSubviewToFront(dropIndicatorLine)
        bringSubviewToFront(backButton)
        bringSubviewToFront(forwardButton)
        bringSubviewToFront(reloadButton)
        bringSubviewToFront(plusButton)
        needsLayout = true
        layout()
    }

    private func bringSubviewToFront(_ subview: NSView) {
        subview.removeFromSuperview()
        addSubview(subview)
    }

    override func layout() {
        super.layout()
        bottomBorder.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)

        let leftPadding: CGFloat = 8
        let rightPadding: CGFloat = 8
        let navButtonSize: CGFloat = 26
        let navSpacing: CGFloat = 2
        let navToTabsSpacing: CGFloat = 8
        let plusWidth: CGFloat = 26
        let plusSpacing: CGFloat = 4
        let itemSpacing: CGFloat = 3
        let tabHeight: CGFloat = 28
        let groupHeight: CGFloat = 24
        let tabY = (bounds.height - tabHeight) / 2
        let groupY = (bounds.height - groupHeight) / 2
        let navY = (bounds.height - navButtonSize) / 2

        var navX = leftPadding
        backButton.frame = NSRect(x: navX, y: navY, width: navButtonSize, height: navButtonSize)
        navX += navButtonSize + navSpacing

        forwardButton.frame = NSRect(x: navX, y: navY, width: navButtonSize, height: navButtonSize)
        navX += navButtonSize + navSpacing

        reloadButton.frame = NSRect(x: navX, y: navY, width: navButtonSize, height: navButtonSize)
        navX += navButtonSize + navToTabsSpacing

        let tabsStartX = navX

        guard !itemViews.isEmpty else {
            plusButton.frame = NSRect(x: tabsStartX, y: (bounds.height - plusWidth) / 2, width: plusWidth, height: plusWidth)
            return
        }

        // Calculate fixed width used by group pills
        var totalGroupWidth: CGFloat = 0
        var tabCount = 0
        for view in itemViews {
            if let groupView = view as? StripeGroupView {
                totalGroupWidth += groupView.desiredWidth
            } else if view is StripeTabView {
                tabCount += 1
            }
        }

        let totalItems = itemViews.count
        let totalSpacing = CGFloat(max(0, totalItems - 1)) * itemSpacing
        let availableWidth = bounds.width - tabsStartX - rightPadding - plusWidth - plusSpacing - totalSpacing - totalGroupWidth

        let maxTabWidth: CGFloat = 180
        let minTabWidth: CGFloat = 32
        let calculatedTabWidth = tabCount > 0 ? max(minTabWidth, min(maxTabWidth, availableWidth / CGFloat(tabCount))) : 0

        var currentX = tabsStartX
        for view in itemViews {
            if let groupView = view as? StripeGroupView {
                let w = groupView.desiredWidth
                groupView.frame = NSRect(x: currentX, y: groupY, width: w, height: groupHeight)
                currentX += w + itemSpacing
            } else if let tabView = view as? StripeTabView {
                tabView.frame = NSRect(x: currentX, y: tabY, width: calculatedTabWidth, height: tabHeight)
                currentX += calculatedTabWidth + itemSpacing
            }
        }

        let plusX = min(bounds.width - rightPadding - plusWidth, currentX - itemSpacing + plusSpacing)
        plusButton.frame = NSRect(x: plusX, y: (bounds.height - plusWidth) / 2, width: plusWidth, height: plusWidth)
    }

    // MARK: - Drag & Drop Destination

    private func updateDropFeedback(at point: NSPoint) {
        var hitGroup: StripeGroupView?
        for view in itemViews {
            if let groupView = view as? StripeGroupView {
                let isHit = groupView.frame.contains(point)
                groupView.isDropTarget = isHit
                if isHit {
                    hitGroup = groupView
                }
            }
        }

        if hitGroup != nil {
            dropIndicatorLine.isHidden = true
            return
        }

        guard !itemViews.isEmpty else {
            dropIndicatorLine.isHidden = true
            return
        }

        let tabHeight: CGFloat = 26
        let tabY = (bounds.height - tabHeight) / 2
        var indicatorX: CGFloat = itemViews.first!.frame.minX

        if point.x <= itemViews.first!.frame.minX {
            indicatorX = max(4, itemViews.first!.frame.minX - 1.5)
        } else if point.x >= itemViews.last!.frame.maxX {
            indicatorX = itemViews.last!.frame.maxX + 1.5
        } else {
            for view in itemViews {
                if point.x < view.frame.midX {
                    indicatorX = view.frame.minX - 1.5
                    break
                } else if point.x <= view.frame.maxX {
                    indicatorX = view.frame.maxX + 1.5
                    break
                }
            }
        }

        dropIndicatorLine.frame = NSRect(x: indicatorX - 1.25, y: tabY, width: 2.5, height: tabHeight)
        dropIndicatorLine.isHidden = false
        bringSubviewToFront(dropIndicatorLine)
    }

    private func clearDropFeedback() {
        dropIndicatorLine.isHidden = true
        for view in itemViews {
            if let groupView = view as? StripeGroupView {
                groupView.isDropTarget = false
            }
        }
    }

    private func executeDrop(for tabId: UUID, at point: NSPoint) {
        for view in itemViews {
            if let groupView = view as? StripeGroupView, groupView.frame.contains(point) {
                onDropTab?(tabId, groupView, true)
                return
            }
        }

        guard !itemViews.isEmpty else {
            onDropTab?(tabId, nil, true)
            return
        }

        if point.x <= itemViews.first!.frame.minX {
            onDropTab?(tabId, itemViews.first, false)
            return
        }

        if point.x >= itemViews.last!.frame.maxX {
            onDropTab?(tabId, nil, true)
            return
        }

        for view in itemViews {
            if point.x <= view.frame.maxX {
                let dropAfter = point.x >= view.frame.midX
                onDropTab?(tabId, view, dropAfter)
                return
            }
        }

        onDropTab?(tabId, nil, true)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types,
              types.contains(NSPasteboard.PasteboardType("com.sansara.browser.tab")) || types.contains(.string) else {
            return []
        }
        let localPoint = convert(sender.draggingLocation, from: nil)
        updateDropFeedback(at: localPoint)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDropFeedback()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        clearDropFeedback()
        guard let pb = sender.draggingPasteboard.string(forType: NSPasteboard.PasteboardType("com.sansara.browser.tab")) ?? sender.draggingPasteboard.string(forType: .string),
              let tabId = UUID(uuidString: pb) else {
            return false
        }
        let localPoint = convert(sender.draggingLocation, from: nil)
        executeDrop(for: tabId, at: localPoint)
        return true
    }
}

private final class BrowserContentView: NSView {
    var onAppearanceChanged: (() -> Void)?

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = ContentColors.color(for: effectiveAppearance).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = ContentColors.color(for: effectiveAppearance).cgColor
        needsDisplay = true
        onAppearanceChanged?()
    }
}

// MARK: - Content View Controller

/// Content view controller holding the New Tab view, the full-canvas web container,
/// a floating command palette for ⌘L navigation, and a dynamic tab stripe when sidebar is hidden.
public final class BrowserContentViewController: NSViewController, NewTabViewDelegate, NSTextFieldDelegate {

    public let tabManager: TabManager

    private let newTabView = NewTabView()
    private let webContainerView = WebContainerView()

    // Tab stripe (shown when sidebar is collapsed)
    private let tabStripView = TabStripView()
    private var contentTopToStripe: NSLayoutConstraint!
    private var contentTopToView: NSLayoutConstraint!

    // Floating command bar overlay (Arc-style ⌘L palette over active pages)
    private let commandOverlay = NSView()
    private let commandCard = NSBox()
    private let commandIcon = NSImageView()
    private let commandField = NSTextField()
    private let commandReturnBadge = NSBox()
    private let commandReturnLabel = NSTextField(labelWithString: "↵")
    private let commandBookmarkButton = NSButton()
    private let commandSuggestionsDropdown = SearchHistoryDropdownView()

    private var sidebarVisible: Bool = true
    public var onToggleSidebar: (() -> Void)?

    public init(tabManager: TabManager) {
        self.tabManager = tabManager
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let bgView = BrowserContentView()
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = ContentColors.color(for: bgView.effectiveAppearance).cgColor
        bgView.onAppearanceChanged = { [weak self] in
            guard let self = self else { return }
            self.tabStripView.viewDidChangeEffectiveAppearance()
            self.updateCommandCardAppearance()
            if !self.sidebarVisible {
                self.reloadTabStripe()
            }
        }
        view = bgView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTabStripe()
        setupCommandOverlay()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsManager.didChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange() {
        let tab = tabManager.activeTab
        if tab == nil || (tab?.isNewTabPage ?? false) {
            update(for: tab)
        }
    }

    // MARK: - Tab Stripe

    private func setupTabStripe() {
        tabStripView.translatesAutoresizingMaskIntoConstraints = false
        tabStripView.isHidden = true
        tabStripView.onBack = { [weak self] in
            self?.tabManager.activeTab?.goBack()
        }
        tabStripView.onForward = { [weak self] in
            self?.tabManager.activeTab?.goForward()
        }
        tabStripView.onReload = { [weak self] in
            self?.tabManager.activeTab?.reload()
        }
        tabStripView.onNewTab = { [weak self] in
            self?.tabManager.createTab(url: nil, select: true)
        }
        tabStripView.onContextMenu = { [weak self] in
            self?.createEmptyTabStripContextMenu()
        }
        tabStripView.onDropTab = { [weak self] draggedTabId, targetView, dropAfter in
            self?.handleTabStripDrop(draggedTabId: draggedTabId, targetView: targetView, dropAfter: dropAfter)
        }
        view.addSubview(tabStripView)

        NSLayoutConstraint.activate([
            tabStripView.topAnchor.constraint(equalTo: view.topAnchor),
            tabStripView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStripView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStripView.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    private func handleTabStripDrop(draggedTabId: UUID, targetView: NSView?, dropAfter: Bool) {
        if let groupView = targetView as? StripeGroupView {
            if dropAfter {
                tabManager.addTabs([draggedTabId], to: groupView.group.id)
                groupView.group.isCollapsed = false
            } else {
                tabManager.removeTabFromGroup(id: draggedTabId)
                if let firstTab = tabManager.tabs.first(where: { $0.groupId == groupView.group.id }) {
                    tabManager.moveTab(id: draggedTabId, beforeOrAfter: firstTab.id, placeAfter: false)
                }
            }
            reloadTabStripe()
            return
        }

        if let tabView = targetView as? StripeTabView, let targetTab = tabView.tab {
            guard targetTab.id != draggedTabId else { return }
            if let targetGroupId = targetTab.groupId {
                tabManager.addTabs([draggedTabId], to: targetGroupId)
            } else {
                tabManager.removeTabFromGroup(id: draggedTabId)
            }
            tabManager.moveTab(id: draggedTabId, beforeOrAfter: targetTab.id, placeAfter: dropAfter)
            reloadTabStripe()
            return
        }

        // Dropped at end or empty area
        tabManager.removeTabFromGroup(id: draggedTabId)
        tabManager.moveTabToEnd(id: draggedTabId)
        reloadTabStripe()
    }

    private func setupUI() {
        // Web container
        webContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webContainerView)

        // New tab view
        newTabView.delegate = self
        newTabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newTabView)

        contentTopToStripe = webContainerView.topAnchor.constraint(equalTo: tabStripView.bottomAnchor)
        contentTopToView = webContainerView.topAnchor.constraint(equalTo: view.topAnchor)

        NSLayoutConstraint.activate([
            contentTopToView,
            webContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            newTabView.topAnchor.constraint(equalTo: view.topAnchor),
            newTabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newTabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newTabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    public func setSidebarVisible(_ visible: Bool) {
        sidebarVisible = visible
        tabStripView.isHidden = visible

        if visible {
            contentTopToStripe.isActive = false
            contentTopToView.isActive = true
        } else {
            contentTopToView.isActive = false
            contentTopToStripe.isActive = true
            reloadTabStripe()
        }
    }

    public func reloadTabStripe() {
        guard !sidebarVisible else { return }

        // Compute expected item descriptors
        var expectedDescriptors: [TabStripView.ItemDescriptor] = []
        var processedGroupIds = Set<UUID>()

        for tab in tabManager.tabs {
            if let groupId = tab.groupId, let group = tabManager.groups.first(where: { $0.id == groupId }) {
                if !processedGroupIds.contains(groupId) {
                    processedGroupIds.insert(groupId)
                    expectedDescriptors.append(.group(id: group.id, isCollapsed: group.isCollapsed))
                }
                if !group.isCollapsed {
                    expectedDescriptors.append(.tab(id: tab.id))
                }
            } else {
                expectedDescriptors.append(.tab(id: tab.id))
            }
        }

        for group in tabManager.groups where !processedGroupIds.contains(group.id) {
            expectedDescriptors.append(.group(id: group.id, isCollapsed: group.isCollapsed))
        }

        let isImageMode = (tabManager.activeTab?.isNewTabPage ?? true) && SettingsManager.shared.newTabPageMode == .image

        // If structure matches exactly, update in place without recreating views (preserves mouse tracking for drags)
        if tabStripView.currentItemDescriptors == expectedDescriptors && !expectedDescriptors.isEmpty {
            for view in tabStripView.itemViews {
                if let groupView = view as? StripeGroupView,
                   let group = tabManager.groups.first(where: { $0.id == groupView.group.id }) {
                    let groupTabs = tabManager.tabs.filter { $0.groupId == group.id }
                    groupView.configure(group: group, tabCount: groupTabs.count)
                } else if let tabView = view as? StripeTabView,
                          let tab = tabView.tab,
                          let currentTab = tabManager.tabs.first(where: { $0.id == tab.id }) {
                    let isSelected = (currentTab.id == tabManager.activeTabId)
                    let groupColor = currentTab.groupId.flatMap { gid in tabManager.groups.first(where: { $0.id == gid })?.color }
                    tabView.configure(tab: currentTab, isSelected: isSelected, groupColor: groupColor, isImageMode: isImageMode)
                }
            }
            tabStripView.needsLayout = true
            tabStripView.layoutSubtreeIfNeeded()
            return
        }

        var itemViews: [NSView] = []
        processedGroupIds.removeAll()

        for tab in tabManager.tabs {
            if let groupId = tab.groupId, let group = tabManager.groups.first(where: { $0.id == groupId }) {
                if !processedGroupIds.contains(groupId) {
                    processedGroupIds.insert(groupId)
                    let groupTabs = tabManager.tabs.filter { $0.groupId == groupId }
                    let groupView = StripeGroupView(group: group, tabCount: groupTabs.count)
                    groupView.onToggleCollapse = { [weak self] in
                        self?.tabManager.toggleGroupCollapsed(id: group.id)
                        self?.reloadTabStripe()
                    }
                    groupView.onDoubleClick = { [weak self] in
                        guard let self = self else { return }
                        self.promptRenameGroup(group)
                    }
                    groupView.onContextMenu = { [weak self] in
                        self?.createGroupContextMenu(for: group)
                    }
                    itemViews.append(groupView)
                }
                if !group.isCollapsed {
                    let tabView = StripeTabView()
                    let isSelected = (tab.id == tabManager.activeTabId)
                    tabView.configure(tab: tab, isSelected: isSelected, groupColor: group.color, isImageMode: isImageMode)
                    tabView.onSelect = { [weak self] in
                        self?.tabManager.selectTab(id: tab.id)
                    }
                    tabView.onDoubleClick = { [weak tabView] in
                        tabView?.startEditing()
                    }
                    tabView.onClose = { [weak self] in
                        self?.tabManager.closeTab(id: tab.id)
                    }
                    tabView.onContextMenu = { [weak self, weak tab] in
                        guard let tab = tab else { return nil }
                        return self?.createTabContextMenu(for: tab)
                    }
                    itemViews.append(tabView)
                }
            } else {
                let tabView = StripeTabView()
                let isSelected = (tab.id == tabManager.activeTabId)
                tabView.configure(tab: tab, isSelected: isSelected, groupColor: nil, isImageMode: isImageMode)
                tabView.onSelect = { [weak self] in
                    self?.tabManager.selectTab(id: tab.id)
                }
                tabView.onDoubleClick = { [weak tabView] in
                    tabView?.startEditing()
                }
                tabView.onClose = { [weak self] in
                    self?.tabManager.closeTab(id: tab.id)
                }
                tabView.onContextMenu = { [weak self, weak tab] in
                    guard let tab = tab else { return nil }
                    return self?.createTabContextMenu(for: tab)
                }
                itemViews.append(tabView)
            }
        }

        // Empty groups
        for group in tabManager.groups where !processedGroupIds.contains(group.id) {
            let groupView = StripeGroupView(group: group, tabCount: 0)
            groupView.onToggleCollapse = { [weak self] in
                self?.tabManager.toggleGroupCollapsed(id: group.id)
                self?.reloadTabStripe()
            }
            groupView.onDoubleClick = { [weak self] in
                guard let self = self else { return }
                self.promptRenameGroup(group)
            }
            groupView.onContextMenu = { [weak self] in
                self?.createGroupContextMenu(for: group)
            }
            itemViews.append(groupView)
        }

        tabStripView.setItems(itemViews)
    }

    // MARK: - Tab Strip Context Menus

    private func createEmptyTabStripContextMenu() -> NSMenu {
        let menu = NSMenu()
        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(menuNewTab), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

        let newGroupItem = NSMenuItem(title: "New Group…", action: #selector(menuNewGroupEmpty), keyEquivalent: "")
        newGroupItem.target = self
        menu.addItem(newGroupItem)

        if !tabManager.closedHistory.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let reopenItem = NSMenuItem(title: "Reopen Closed Tab", action: #selector(menuReopenClosedTab), keyEquivalent: "T")
            reopenItem.target = self
            menu.addItem(reopenItem)
        }
        return menu
    }

    @objc private func menuNewGroupEmpty() {
        TabGroupDialog.show(title: "New Tab Group", actionButtonTitle: "Create") { [weak self] name, color in
            guard let self = self, let name = name, let color = color else { return }
            self.tabManager.createGroup(name: name, color: color, tabIds: [])
            self.reloadTabStripe()
        }
    }

    @objc private func menuReopenClosedTab() {
        tabManager.reopenClosedTab()
        reloadTabStripe()
    }

    private func createGroupContextMenu(for group: TabGroup) -> NSMenu {
        let menu = NSMenu()

        let newTabItem = NSMenuItem(title: "New Tab in Group", action: #selector(menuAddTabToGroup(_:)), keyEquivalent: "")
        newTabItem.target = self
        newTabItem.representedObject = group
        menu.addItem(newTabItem)

        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(title: "Rename Group…", action: #selector(menuRenameGroup(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = group
        menu.addItem(renameItem)

        let colorMenuItem = NSMenuItem(title: "Change Color", action: nil, keyEquivalent: "")
        let colorSubmenu = NSMenu()
        for color in TabGroupColor.allCases {
            let item = NSMenuItem(title: color.rawValue, action: #selector(menuChangeGroupColor(_:)), keyEquivalent: "")
            item.target = self
            item.image = color.circleImage(size: 12)
            item.representedObject = (group, color)
            if color == group.color {
                item.state = .on
            }
            colorSubmenu.addItem(item)
        }
        colorMenuItem.submenu = colorSubmenu
        menu.addItem(colorMenuItem)

        menu.addItem(NSMenuItem.separator())

        let ungroupItem = NSMenuItem(title: "Ungroup", action: #selector(menuUngroupGroup(_:)), keyEquivalent: "")
        ungroupItem.target = self
        ungroupItem.representedObject = group
        menu.addItem(ungroupItem)

        let closeGroupItem = NSMenuItem(title: "Close Group", action: #selector(menuCloseGroup(_:)), keyEquivalent: "")
        closeGroupItem.target = self
        closeGroupItem.representedObject = group
        menu.addItem(closeGroupItem)

        return menu
    }

    public func createTabContextMenu(for tab: BrowserTab) -> NSMenu {
        let menu = NSMenu()

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(menuNewTab), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

        let renameItem = NSMenuItem(title: "Rename Tab…", action: #selector(menuRenameTab(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = tab
        menu.addItem(renameItem)

        menu.addItem(NSMenuItem.separator())

        let newGroupItem = NSMenuItem(title: "New Folder with Tab…", action: #selector(menuNewGroupWithTab(_:)), keyEquivalent: "")
        newGroupItem.target = self
        newGroupItem.representedObject = tab
        menu.addItem(newGroupItem)

        let moveToGroupItem = NSMenuItem(title: "Move to Group", action: nil, keyEquivalent: "")
        let groupSubmenu = NSMenu()
        if !tabManager.groups.isEmpty {
            for group in tabManager.groups {
                let item = NSMenuItem(title: group.name, action: #selector(menuMoveTabToGroup(_:)), keyEquivalent: "")
                item.target = self
                item.image = group.color.circleImage(size: 12)
                item.representedObject = (tab, group)
                if tab.groupId == group.id {
                    item.state = .on
                }
                groupSubmenu.addItem(item)
            }
            if tab.groupId != nil {
                groupSubmenu.addItem(NSMenuItem.separator())
                let removeItem = NSMenuItem(title: "Remove from Group", action: #selector(menuRemoveTabFromGroup(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = tab
                groupSubmenu.addItem(removeItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: "No Groups", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            groupSubmenu.addItem(emptyItem)
        }
        moveToGroupItem.submenu = groupSubmenu
        menu.addItem(moveToGroupItem)

        menu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(title: "Reload Tab", action: #selector(menuReloadTab(_:)), keyEquivalent: "r")
        reloadItem.target = self
        reloadItem.representedObject = tab
        menu.addItem(reloadItem)

        let duplicateItem = NSMenuItem(title: "Duplicate Tab", action: #selector(menuDuplicateTab(_:)), keyEquivalent: "")
        duplicateItem.target = self
        duplicateItem.representedObject = tab
        menu.addItem(duplicateItem)

        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "Close Tab", action: #selector(menuCloseTab(_:)), keyEquivalent: "w")
        closeItem.target = self
        closeItem.representedObject = tab
        menu.addItem(closeItem)

        let closeOthersItem = NSMenuItem(title: "Close Other Tabs", action: #selector(menuCloseOtherTabs(_:)), keyEquivalent: "")
        closeOthersItem.target = self
        closeOthersItem.representedObject = tab
        menu.addItem(closeOthersItem)

        return menu
    }

    // MARK: - Tab Strip Actions

    @objc private func menuNewTab() {
        tabManager.createTab(url: nil, select: true)
    }

    public func promptRenameGroup(_ group: TabGroup) {
        TabGroupDialog.promptRename(currentName: group.name) { [weak self] newName in
            guard let self = self, let newName = newName else { return }
            self.tabManager.renameGroup(id: group.id, newName: newName)
            self.reloadTabStripe()
        }
    }

    public func startRenameTab(_ tab: BrowserTab) {
        for view in tabStripView.itemViews {
            if let tabView = view as? StripeTabView, tabView.tab?.id == tab.id {
                tabView.startEditing()
                return
            }
        }
        promptRenameTab(tab)
    }

    public func promptRenameTab(_ tab: BrowserTab) {
        TabGroupDialog.promptRenameTab(currentName: tab.title) { [weak self] newTitle in
            guard let self = self, let newTitle = newTitle else { return }
            tab.rename(to: newTitle)
            self.reloadTabStripe()
        }
    }

    @objc private func menuRenameGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        promptRenameGroup(group)
    }

    @objc private func menuRenameTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        startRenameTab(tab)
    }

    @objc private func menuAddTabToGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.createTab(inGroup: group.id, select: true)
        reloadTabStripe()
    }

    @objc private func menuChangeGroupColor(_ sender: NSMenuItem) {
        guard let tuple = sender.representedObject as? (TabGroup, TabGroupColor) else { return }
        tabManager.setGroupColor(id: tuple.0.id, color: tuple.1)
        reloadTabStripe()
    }

    @objc private func menuUngroupGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.ungroup(groupId: group.id)
        reloadTabStripe()
    }

    @objc private func menuCloseGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.closeGroup(groupId: group.id)
        reloadTabStripe()
    }

    @objc private func menuNewGroupWithTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        TabGroupDialog.show(title: "New Tab Group", actionButtonTitle: "Create") { [weak self] name, color in
            guard let self = self, let name = name, let color = color else { return }
            self.tabManager.createGroup(name: name, color: color, tabIds: [tab.id])
            self.reloadTabStripe()
        }
    }

    @objc private func menuMoveTabToGroup(_ sender: NSMenuItem) {
        guard let tuple = sender.representedObject as? (BrowserTab, TabGroup) else { return }
        tabManager.addTabs([tuple.0.id], to: tuple.1.id)
        reloadTabStripe()
    }

    @objc private func menuRemoveTabFromGroup(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tabManager.removeTabFromGroup(id: tab.id)
        reloadTabStripe()
    }

    @objc private func menuReloadTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tab.reload()
    }

    @objc private func menuDuplicateTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tabManager.duplicateTab(id: tab.id)
    }

    @objc private func menuCloseTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tabManager.closeTab(id: tab.id)
    }

    @objc private func menuCloseOtherTabs(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tabManager.closeOtherTabs(except: tab.id)
    }

    // MARK: - Command Overlay

    private func setupCommandOverlay() {
        commandOverlay.wantsLayer = true
        commandOverlay.layer?.backgroundColor = NSColor.shadowColor.withAlphaComponent(0.25).cgColor
        commandOverlay.translatesAutoresizingMaskIntoConstraints = false
        commandOverlay.isHidden = true
        view.addSubview(commandOverlay)

        commandCard.boxType = .custom
        commandCard.borderWidth = 1.0
        commandCard.cornerRadius = 23.0
        commandCard.translatesAutoresizingMaskIntoConstraints = false
        commandOverlay.addSubview(commandCard)

        let searchSymbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        commandIcon.image = searchSymbol?.withSymbolConfiguration(iconConfig)
        commandIcon.contentTintColor = .secondaryLabelColor
        commandIcon.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandIcon)

        commandReturnBadge.boxType = .custom
        commandReturnBadge.borderWidth = 1.0
        commandReturnBadge.borderColor = .separatorColor
        commandReturnBadge.cornerRadius = 5.0
        commandReturnBadge.fillColor = .quaternaryLabelColor
        commandReturnBadge.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandReturnBadge)

        commandReturnLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        commandReturnLabel.textColor = .secondaryLabelColor
        commandReturnLabel.translatesAutoresizingMaskIntoConstraints = false
        commandReturnBadge.addSubview(commandReturnLabel)

        commandBookmarkButton.isBordered = false
        commandBookmarkButton.title = ""
        let starConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        commandBookmarkButton.image = NSImage(systemSymbolName: "star", accessibilityDescription: "Bookmark")?.withSymbolConfiguration(starConfig)
        commandBookmarkButton.contentTintColor = .secondaryLabelColor
        commandBookmarkButton.target = self
        commandBookmarkButton.action = #selector(commandBookmarkToggled)
        commandBookmarkButton.toolTip = "Bookmark this tab"
        commandBookmarkButton.wantsLayer = true
        commandBookmarkButton.layer?.cornerRadius = 4.0
        commandBookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandBookmarkButton)

        commandField.isBordered = false
        commandField.drawsBackground = false
        commandField.focusRingType = .none
        commandField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        commandField.textColor = .labelColor
        commandField.placeholderString = "Search or enter URL"
        commandField.alignment = .left
        commandField.cell?.wraps = false
        commandField.cell?.isScrollable = true
        commandField.delegate = self
        commandField.target = self
        commandField.action = #selector(commandSubmitted)
        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandField)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(commandOverlayBackgroundClicked(_:)))
        commandOverlay.addGestureRecognizer(clickGesture)

        // Command suggestions dropdown
        commandSuggestionsDropdown.translatesAutoresizingMaskIntoConstraints = false
        commandSuggestionsDropdown.isHidden = true
        commandOverlay.addSubview(commandSuggestionsDropdown)

        commandSuggestionsDropdown.onSelect = { [weak self] item in
            guard let self = self else { return }
            self.commandSuggestionsDropdown.hide()
            self.commandOverlay.isHidden = true
            self.view.window?.makeFirstResponder(nil)
            self.navigateTo(query: item.url.absoluteString)
        }

        NSLayoutConstraint.activate([
            commandOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            commandOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            commandCard.centerXAnchor.constraint(equalTo: commandOverlay.centerXAnchor),
            commandCard.topAnchor.constraint(equalTo: commandOverlay.topAnchor, constant: 50),
            commandCard.widthAnchor.constraint(equalToConstant: 480),
            commandCard.heightAnchor.constraint(equalToConstant: 46),

            commandIcon.leadingAnchor.constraint(equalTo: commandCard.leadingAnchor, constant: 16),
            commandIcon.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),
            commandIcon.widthAnchor.constraint(equalToConstant: 18),
            commandIcon.heightAnchor.constraint(equalToConstant: 18),

            commandReturnBadge.trailingAnchor.constraint(equalTo: commandCard.trailingAnchor, constant: -14),
            commandReturnBadge.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),
            commandReturnBadge.widthAnchor.constraint(equalToConstant: 22),
            commandReturnBadge.heightAnchor.constraint(equalToConstant: 22),

            commandReturnLabel.centerXAnchor.constraint(equalTo: commandReturnBadge.centerXAnchor),
            commandReturnLabel.centerYAnchor.constraint(equalTo: commandReturnBadge.centerYAnchor),

            commandBookmarkButton.trailingAnchor.constraint(equalTo: commandReturnBadge.leadingAnchor, constant: -6),
            commandBookmarkButton.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),
            commandBookmarkButton.widthAnchor.constraint(equalToConstant: 22),
            commandBookmarkButton.heightAnchor.constraint(equalToConstant: 22),

            commandField.leadingAnchor.constraint(equalTo: commandIcon.trailingAnchor, constant: 10),
            commandField.trailingAnchor.constraint(equalTo: commandBookmarkButton.leadingAnchor, constant: -6),
            commandField.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),

            commandSuggestionsDropdown.topAnchor.constraint(equalTo: commandCard.bottomAnchor, constant: 6),
            commandSuggestionsDropdown.centerXAnchor.constraint(equalTo: commandCard.centerXAnchor),
            commandSuggestionsDropdown.widthAnchor.constraint(equalTo: commandCard.widthAnchor)
        ])

        updateCommandCardAppearance()
    }

    private func updateCommandCardAppearance() {
        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        commandCard.fillColor = isDark ? .black : .white
        commandCard.borderColor = isDark ? NSColor(white: 0.0, alpha: 0.40) : NSColor(white: 0.0, alpha: 0.08)
        commandCard.borderWidth = 0.5
        commandReturnBadge.borderColor = isDark ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.08)
        commandReturnBadge.fillColor = isDark ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.05)
        commandReturnBadge.borderWidth = 0.5
        commandReturnLabel.textColor = isDark ? .white : .secondaryLabelColor
    }

    @objc private func commandOverlayBackgroundClicked(_ gesture: NSClickGestureRecognizer) {
        let point = gesture.location(in: commandOverlay)
        if !commandCard.frame.contains(point) && !commandSuggestionsDropdown.frame.contains(point) {
            commandSuggestionsDropdown.hide()
            commandOverlay.isHidden = true
            view.window?.makeFirstResponder(nil)
        }
    }

    // MARK: - Updates

    public func updateNavButtons() {
        let tab = tabManager.activeTab
        tabStripView.updateNavButtons(canGoBack: tab?.canGoBack ?? false, canGoForward: tab?.canGoForward ?? false)
    }

    public func update(for tab: BrowserTab?) {
        commandSuggestionsDropdown.hide()
        commandOverlay.isHidden = true

        let isImageNewTab = (tab?.isNewTabPage ?? true) && SettingsManager.shared.newTabPageMode == .image
        tabStripView.setImageModeBackground(isImageNewTab)
        tabStripView.updateNavButtons(canGoBack: tab?.canGoBack ?? false, canGoForward: tab?.canGoForward ?? false)

        if !sidebarVisible {
            reloadTabStripe()
        }

        guard let tab = tab else {
            newTabView.isHidden = false
            webContainerView.isHidden = true
            newTabView.setMode(SettingsManager.shared.newTabPageMode)
            return
        }

        if tab.isNewTabPage {
            newTabView.isHidden = false
            webContainerView.isHidden = true
            newTabView.setMode(SettingsManager.shared.newTabPageMode)
        } else {
            newTabView.isHidden = true
            webContainerView.isHidden = false
            webContainerView.display(tab: tab)
        }
    }

    public func focusAddressBar() {
        guard let tab = tabManager.activeTab else { return }
        if tab.isNewTabPage {
            newTabView.focus()
        } else {
            // Smart Omnibar: Display SSL lock for secure sites or globe for standard web
            let symbol: String
            if let scheme = tab.url?.scheme?.lowercased() {
                symbol = scheme == "https" ? "lock.fill" : "globe"
            } else {
                symbol = "magnifyingglass"
            }
            let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            commandIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Security")?.withSymbolConfiguration(iconConfig)
            commandIcon.contentTintColor = symbol == "lock.fill" ? .secondaryLabelColor : .tertiaryLabelColor

            updateCommandCardAppearance()
            commandField.stringValue = tab.url?.absoluteString ?? ""
            updateBookmarkButtonState()
            commandSuggestionsDropdown.hide()
            commandOverlay.isHidden = false
            view.window?.makeFirstResponder(commandField)
            commandField.selectText(nil)
        }
    }

    private func updateBookmarkButtonState() {
        guard let tab = tabManager.activeTab, let url = tab.url else {
            commandBookmarkButton.isHidden = true
            return
        }
        commandBookmarkButton.isHidden = false
        let isBookmarked = BookmarkManager.shared.isBookmarked(url: url)
        let symbolName = isBookmarked ? "star.fill" : "star"
        let starConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        commandBookmarkButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Bookmark")?.withSymbolConfiguration(starConfig)
        commandBookmarkButton.contentTintColor = isBookmarked ? .controlAccentColor : .secondaryLabelColor
        commandBookmarkButton.toolTip = isBookmarked ? "Remove Bookmark" : "Bookmark this tab"
    }

    @objc private func commandBookmarkToggled() {
        guard let tab = tabManager.activeTab, let url = tab.url else { return }
        BookmarkManager.shared.toggleBookmark(title: tab.title, url: url)
        updateBookmarkButtonState()
    }

    @objc private func commandSubmitted() {
        let text = commandField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        commandSuggestionsDropdown.hide()
        commandOverlay.isHidden = true
        view.window?.makeFirstResponder(nil)
        guard !text.isEmpty else { return }
        navigateTo(query: text)
    }

    public override func cancelOperation(_ sender: Any?) {
        if !commandSuggestionsDropdown.isHidden {
            commandSuggestionsDropdown.hide()
            return
        }
        if !commandOverlay.isHidden {
            commandOverlay.isHidden = true
            view.window?.makeFirstResponder(nil)
        }
    }

    // MARK: - NSTextFieldDelegate

    public func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === commandField else { return }
        let query = commandField.stringValue
        let items = SearchSuggestionsProvider.shared.suggestions(for: query)
        if items.isEmpty {
            commandSuggestionsDropdown.hide()
        } else {
            commandSuggestionsDropdown.update(items: items)
        }
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === commandField, !commandSuggestionsDropdown.isHidden else { return false }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            commandSuggestionsDropdown.selectNext()
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            commandSuggestionsDropdown.selectPrevious()
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let item = commandSuggestionsDropdown.selectedItem {
                commandSuggestionsDropdown.hide()
                commandOverlay.isHidden = true
                view.window?.makeFirstResponder(nil)
                navigateTo(query: item.url.absoluteString)
                return true
            }
            commandSuggestionsDropdown.hide()
            return false
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            commandSuggestionsDropdown.hide()
            return true
        }
        return false
    }

    // MARK: - NewTabViewDelegate

    public func newTabView(_ view: NewTabView, didSubmitQuery query: String) {
        navigateTo(query: query)
    }

    private func navigateTo(query: String) {
        guard let tab = tabManager.activeTab else { return }
        let targetURL = URLHelper.resolve(input: query)
        tab.load(url: targetURL)
        update(for: tab)
    }
}
