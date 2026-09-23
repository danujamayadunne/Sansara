import AppKit

// MARK: - Stripe Tab View (polished, Apple-quality tab chip for the horizontal strip)

private final class StripeTabView: NSView {

    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?

    private let centerStack = NSStackView()
    private let faviconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isTabSelected = false

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
        layer?.cornerRadius = 7.0
        layer?.masksToBounds = true

        // Favicon (16x16, crisp)
        faviconView.imageScaling = .scaleProportionallyUpOrDown
        faviconView.wantsLayer = true
        faviconView.layer?.cornerRadius = 2.0
        faviconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        faviconView.setContentHuggingPriority(.required, for: .horizontal)
        faviconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.3, alpha: 1.0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.alignment = .center
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Centered stack holding favicon and title
        centerStack.orientation = .horizontal
        centerStack.spacing = 6
        centerStack.alignment = .centerY
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(faviconView)
        centerStack.addArrangedSubview(titleLabel)
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
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            faviconView.widthAnchor.constraint(equalToConstant: 16),
            faviconView.heightAnchor.constraint(equalToConstant: 16),

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
        return self
    }

    func configure(tab: BrowserTab, isSelected: Bool) {
        self.isTabSelected = isSelected

        // Scale favicon to 16x16
        let size = NSSize(width: 16, height: 16)
        let scaled = NSImage(size: size, flipped: false) { rect in
            tab.favicon.draw(in: rect)
            return true
        }
        faviconView.image = scaled
        titleLabel.stringValue = tab.title.isEmpty ? "New Tab" : tab.title
        updateAppearance()
    }

    private func updateAppearance() {
        if isTabSelected {
            layer?.backgroundColor = NSColor(white: 0.90, alpha: 1.0).cgColor
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            titleLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        } else if isHovered {
            layer?.backgroundColor = NSColor(white: 0.92, alpha: 1.0).cgColor
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
            titleLabel.textColor = NSColor(white: 0.2, alpha: 1.0)
        } else {
            layer?.backgroundColor = NSColor(white: 0.955, alpha: 1.0).cgColor
            titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
            titleLabel.textColor = NSColor(white: 0.3, alpha: 1.0)
        }
        closeButton.isHidden = !isHovered
    }

    @objc private func didClose() {
        onClose?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !closeButton.isHidden && closeButton.frame.contains(point) {
            return
        }
        onSelect?()
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
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            updateAppearance()
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            updateAppearance()
        }
    }
}

// MARK: - Tab Strip View (manages dynamic non-overflowing tab layout like Chrome / Safari)

private final class TabStripView: NSView {

    private var tabViews: [StripeTabView] = []
    let plusButton = NSButton()
    private let bottomBorder = NSView()
    var onNewTab: (() -> Void)?

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
        layer?.backgroundColor = NSColor(white: 0.985, alpha: 1.0).cgColor

        bottomBorder.wantsLayer = true
        bottomBorder.layer?.backgroundColor = NSColor(white: 0.90, alpha: 1.0).cgColor
        addSubview(bottomBorder)

        let plusImage = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        plusButton.image = plusImage?.withSymbolConfiguration(config)
        plusButton.contentTintColor = NSColor(white: 0.45, alpha: 1.0)
        plusButton.isBordered = false
        plusButton.title = ""
        plusButton.wantsLayer = true
        plusButton.layer?.cornerRadius = 5.0
        plusButton.target = self
        plusButton.action = #selector(didClickPlus)
        plusButton.toolTip = "New Tab"
        addSubview(plusButton)
    }

    @objc private func didClickPlus() {
        onNewTab?()
    }

    func setTabViews(_ views: [StripeTabView]) {
        tabViews.forEach { $0.removeFromSuperview() }
        tabViews = views
        for v in views {
            addSubview(v)
        }
        needsLayout = true
        layout()
    }

    override func layout() {
        super.layout()
        bottomBorder.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)

        let leftPadding: CGFloat = 8
        let rightPadding: CGFloat = 8
        let plusWidth: CGFloat = 26
        let plusSpacing: CGFloat = 4
        let tabSpacing: CGFloat = 3
        let tabHeight: CGFloat = 28
        let y = (bounds.height - tabHeight) / 2

        guard !tabViews.isEmpty else {
            plusButton.frame = NSRect(x: leftPadding, y: (bounds.height - plusWidth) / 2, width: plusWidth, height: plusWidth)
            return
        }

        let availableWidth = bounds.width - leftPadding - rightPadding - plusWidth - plusSpacing
        let N = CGFloat(tabViews.count)
        let totalSpacing = CGFloat(max(0, tabViews.count - 1)) * tabSpacing
        let maxTabWidth: CGFloat = 180
        let minTabWidth: CGFloat = 32

        // Shrinks gracefully as more tabs are added, without ever overflowing
        let calculatedWidth = max(minTabWidth, min(maxTabWidth, (availableWidth - totalSpacing) / N))

        var currentX = leftPadding
        for tabView in tabViews {
            tabView.frame = NSRect(x: currentX, y: y, width: calculatedWidth, height: tabHeight)
            currentX += calculatedWidth + tabSpacing
        }

        let plusX = min(bounds.width - rightPadding - plusWidth, currentX - tabSpacing + plusSpacing)
        plusButton.frame = NSRect(x: plusX, y: (bounds.height - plusWidth) / 2, width: plusWidth, height: plusWidth)
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

    private var sidebarVisible: Bool = true

    // Constraints for new tab view
    private var newTabTopToStripe: NSLayoutConstraint!
    private var newTabTopToView: NSLayoutConstraint!

    public init(tabManager: TabManager) {
        self.tabManager = tabManager
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let whiteView = NSView()
        whiteView.wantsLayer = true
        whiteView.layer?.backgroundColor = NSColor.white.cgColor
        view = whiteView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupTabStripe()
        setupUI()
        setupCommandOverlay()
    }

    // MARK: - Tab Stripe

    private func setupTabStripe() {
        tabStripView.translatesAutoresizingMaskIntoConstraints = false
        tabStripView.isHidden = true
        tabStripView.onNewTab = { [weak self] in
            self?.tabManager.createTab(url: nil, select: true)
        }
        view.addSubview(tabStripView)

        NSLayoutConstraint.activate([
            tabStripView.topAnchor.constraint(equalTo: view.topAnchor),
            tabStripView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStripView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStripView.heightAnchor.constraint(equalToConstant: 38),
        ])
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
        newTabTopToStripe = newTabView.topAnchor.constraint(equalTo: tabStripView.bottomAnchor)
        newTabTopToView = newTabView.topAnchor.constraint(equalTo: view.topAnchor)

        NSLayoutConstraint.activate([
            contentTopToView,
            webContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            newTabTopToView,
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
            newTabTopToStripe.isActive = false
            contentTopToView.isActive = true
            newTabTopToView.isActive = true
        } else {
            contentTopToView.isActive = false
            newTabTopToView.isActive = false
            contentTopToStripe.isActive = true
            newTabTopToStripe.isActive = true
            reloadTabStripe()
        }
    }

    public func reloadTabStripe() {
        guard !sidebarVisible else { return }

        var views: [StripeTabView] = []
        for tab in tabManager.tabs {
            let isSelected = (tab.id == tabManager.activeTabId)
            let tabView = StripeTabView()
            tabView.configure(tab: tab, isSelected: isSelected)
            tabView.onSelect = { [weak self] in
                self?.tabManager.selectTab(id: tab.id)
            }
            tabView.onClose = { [weak self] in
                self?.tabManager.closeTab(id: tab.id)
            }
            views.append(tabView)
        }
        tabStripView.setTabViews(views)
    }

    // MARK: - Command Overlay

    private func setupCommandOverlay() {
        commandOverlay.wantsLayer = true
        commandOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        commandOverlay.translatesAutoresizingMaskIntoConstraints = false
        commandOverlay.isHidden = true
        view.addSubview(commandOverlay)

        commandCard.boxType = .custom
        commandCard.borderWidth = 1.0
        commandCard.borderColor = NSColor(white: 0.88, alpha: 1.0)
        commandCard.cornerRadius = 10.0
        commandCard.fillColor = NSColor.white
        commandCard.translatesAutoresizingMaskIntoConstraints = false
        commandOverlay.addSubview(commandCard)

        let searchSymbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        commandIcon.image = searchSymbol?.withSymbolConfiguration(iconConfig)
        commandIcon.contentTintColor = NSColor(white: 0.5, alpha: 1.0)
        commandIcon.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandIcon)

        commandReturnBadge.boxType = .custom
        commandReturnBadge.borderWidth = 1.0
        commandReturnBadge.borderColor = NSColor(white: 0.9, alpha: 1.0)
        commandReturnBadge.cornerRadius = 5.0
        commandReturnBadge.fillColor = NSColor(white: 0.97, alpha: 1.0)
        commandReturnBadge.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandReturnBadge)

        commandReturnLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        commandReturnLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
        commandReturnLabel.translatesAutoresizingMaskIntoConstraints = false
        commandReturnBadge.addSubview(commandReturnLabel)

        commandField.isBordered = false
        commandField.drawsBackground = false
        commandField.focusRingType = .none
        commandField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        commandField.textColor = .labelColor
        commandField.placeholderString = "Search Google or enter URL"
        commandField.alignment = .left
        commandField.cell?.wraps = false
        commandField.cell?.isScrollable = true
        commandField.delegate = self
        commandField.target = self
        commandField.action = #selector(commandSubmitted)
        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandCard.addSubview(commandField)

        NSLayoutConstraint.activate([
            commandOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            commandOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            commandCard.centerXAnchor.constraint(equalTo: commandOverlay.centerXAnchor),
            commandCard.topAnchor.constraint(equalTo: commandOverlay.topAnchor, constant: 50),
            commandCard.widthAnchor.constraint(equalToConstant: 480),
            commandCard.heightAnchor.constraint(equalToConstant: 46),

            commandIcon.leadingAnchor.constraint(equalTo: commandCard.leadingAnchor, constant: 14),
            commandIcon.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),
            commandIcon.widthAnchor.constraint(equalToConstant: 18),
            commandIcon.heightAnchor.constraint(equalToConstant: 18),

            commandReturnBadge.trailingAnchor.constraint(equalTo: commandCard.trailingAnchor, constant: -12),
            commandReturnBadge.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor),
            commandReturnBadge.widthAnchor.constraint(equalToConstant: 22),
            commandReturnBadge.heightAnchor.constraint(equalToConstant: 22),

            commandReturnLabel.centerXAnchor.constraint(equalTo: commandReturnBadge.centerXAnchor),
            commandReturnLabel.centerYAnchor.constraint(equalTo: commandReturnBadge.centerYAnchor),

            commandField.leadingAnchor.constraint(equalTo: commandIcon.trailingAnchor, constant: 10),
            commandField.trailingAnchor.constraint(equalTo: commandReturnBadge.leadingAnchor, constant: -8),
            commandField.centerYAnchor.constraint(equalTo: commandCard.centerYAnchor)
        ])
    }

    // MARK: - Updates

    public func update(for tab: BrowserTab?) {
        commandOverlay.isHidden = true

        if !sidebarVisible {
            reloadTabStripe()
        }

        guard let tab = tab else {
            newTabView.isHidden = false
            webContainerView.isHidden = true
            return
        }

        if tab.isNewTabPage {
            newTabView.isHidden = false
            webContainerView.isHidden = true
            newTabView.focus()
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
            commandField.stringValue = tab.url?.absoluteString ?? ""
            commandOverlay.isHidden = false
            view.window?.makeFirstResponder(commandField)
            commandField.selectText(nil)
        }
    }

    @objc private func commandSubmitted() {
        let text = commandField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        commandOverlay.isHidden = true
        view.window?.makeFirstResponder(nil)
        guard !text.isEmpty else { return }
        navigateTo(query: text)
    }

    public override func cancelOperation(_ sender: Any?) {
        if !commandOverlay.isHidden {
            commandOverlay.isHidden = true
            view.window?.makeFirstResponder(nil)
        }
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
