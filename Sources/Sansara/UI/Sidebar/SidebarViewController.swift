import AppKit

private final class SidebarTableView: NSTableView {
    var onMenuForTab: ((Int) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0 {
            return onMenuForTab?(row)
        }
        return super.menu(for: event)
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        if let column = tableColumns.first, let enclosing = enclosingScrollView {
            column.width = enclosing.contentSize.width
        }
        sizeLastColumnToFit()
    }

    override func layout() {
        super.layout()
        if let column = tableColumns.first, let enclosing = enclosingScrollView {
            let targetWidth = enclosing.contentSize.width
            if targetWidth > 0 && abs(column.width - targetWidth) > 0.5 {
                column.width = targetWidth
                sizeLastColumnToFit()
            }
        }
    }
}

/// Row view that completely eliminates any system blue selection highlights
private final class CleanTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {}
}

/// Cell representing the "+ New tab" action directly after the last tab item
public final class NewTabActionCellView: NSTableCellView {
    public static let identifier = NSUserInterfaceItemIdentifier("NewTabActionCellViewIdentifier")

    public var onClick: (() -> Void)?

    private let containerBox = NSBox()
    private let plusImageView = NSImageView()
    private let label = NSTextField(labelWithString: "New tab")
    private var trackingArea: NSTrackingArea?

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
        containerBox.cornerRadius = 8.0
        containerBox.fillColor = .clear
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerBox)

        let plusSymbol = NSImage(systemSymbolName: "plus", accessibilityDescription: "New tab")
        let plusConfig = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .medium)
        plusImageView.image = plusSymbol?.withSymbolConfiguration(plusConfig)
        plusImageView.contentTintColor = NSColor(white: 0.70, alpha: 1.0)
        plusImageView.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(plusImageView)

        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = NSColor(white: 0.70, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(label)

        NSLayoutConstraint.activate([
            containerBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerBox.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            containerBox.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            plusImageView.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 8),
            plusImageView.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor),
            plusImageView.widthAnchor.constraint(equalToConstant: 12),
            plusImageView.heightAnchor.constraint(equalToConstant: 12),

            label.leadingAnchor.constraint(equalTo: plusImageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor)
        ])
    }

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
        containerBox.fillColor = NSColor(white: 0.96, alpha: 1.0)
        label.textColor = .labelColor
        plusImageView.contentTintColor = .labelColor
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        containerBox.fillColor = .clear
        label.textColor = NSColor(white: 0.70, alpha: 1.0)
        plusImageView.contentTintColor = NSColor(white: 0.70, alpha: 1.0)
    }

    public override func mouseDown(with event: NSEvent) {
        containerBox.fillColor = NSColor(white: 0.92, alpha: 1.0)
        onClick?()
    }

    public override func mouseUp(with event: NSEvent) {
        containerBox.fillColor = .clear
    }
}

/// Pure-white Arc-style sidebar controller matching target design.
public final class SidebarViewController: NSViewController {

    public let tabManager: TabManager
    public var onToggleSidebar: (() -> Void)?

    // Top navigation buttons
    private let navStack = NSStackView()
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!
    private var newTabButton: NSButton!

    // Tabs table
    private let scrollView = NSScrollView()
    private let tableView = SidebarTableView()

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
        setupUI()
        setupTableView()
    }

    private func setupUI() {
        // Top navigation buttons: Back, Forward, Reload, New Tab
        navStack.orientation = .horizontal
        navStack.spacing = 4
        navStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navStack)

        backButton = createNavButton(symbol: "chevron.left", action: #selector(didClickBack), tooltip: "Back")
        forwardButton = createNavButton(symbol: "chevron.right", action: #selector(didClickForward), tooltip: "Forward")
        reloadButton = createNavButton(symbol: "arrow.clockwise", action: #selector(didClickReload), tooltip: "Reload")

        navStack.addArrangedSubview(backButton)
        navStack.addArrangedSubview(forwardButton)
        navStack.addArrangedSubview(reloadButton)

        // Scroll view for tabs (fills from below nav to bottom)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Inset below traffic lights
            navStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            navStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }

    private func createNavButton(symbol: String, action: Selector, tooltip: String) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.title = ""
        let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        button.image = symbolImage?.withSymbolConfiguration(config)
        button.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        button.toolTip = tooltip
        button.wantsLayer = true
        button.layer?.cornerRadius = 5.0
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    /// Update navigation button enabled states based on current tab
    public func updateNavButtons() {
        let tab = tabManager.activeTab
        backButton.isEnabled = tab?.canGoBack ?? false
        forwardButton.isEnabled = tab?.canGoForward ?? false
        backButton.contentTintColor = backButton.isEnabled ? NSColor(white: 0.35, alpha: 1.0) : NSColor(white: 0.75, alpha: 1.0)
        forwardButton.contentTintColor = forwardButton.isEnabled ? NSColor(white: 0.35, alpha: 1.0) : NSColor(white: 0.75, alpha: 1.0)
    }

    @objc private func didClickBack() {
        tabManager.activeTab?.goBack()
    }

    @objc private func didClickForward() {
        tabManager.activeTab?.goForward()
    }

    @objc private func didClickReload() {
        tabManager.activeTab?.reload()
    }

    private func setupTableView() {
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.rowHeight = 28
        tableView.autoresizingMask = [.width]
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TabColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(didSelectTableRow)

        tableView.onMenuForTab = { [weak self] row in
            self?.createContextMenu(for: row)
        }

        scrollView.documentView = tableView
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        tableView.frame.size.width = scrollView.contentSize.width
        if let column = tableView.tableColumns.first {
            column.width = scrollView.contentSize.width
        }
        tableView.sizeLastColumnToFit()
    }

    public func reloadData() {
        tableView.reloadData()
    }

    @objc private func didClickNewTab() {
        tabManager.createTab(url: nil, select: true)
    }

    @objc private func didSelectTableRow() {
        let clickedRow = tableView.clickedRow
        if clickedRow >= 0 && clickedRow < tabManager.tabs.count {
            tabManager.selectTab(id: tabManager.tabs[clickedRow].id)
        } else if clickedRow == tabManager.tabs.count {
            didClickNewTab()
        }
    }

    private func createContextMenu(for row: Int) -> NSMenu? {
        guard row >= 0 && row < tabManager.tabs.count else { return nil }
        let tab = tabManager.tabs[row]
        let menu = NSMenu()

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(didClickNewTab), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

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
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        // Open tabs count + 1 row for "+ New tab"
        return tabManager.tabs.count + 1
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // Prevent system from drawing any blue selection box
        return false
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CleanTableRowView()
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if row < tabManager.tabs.count {
            let tab = tabManager.tabs[row]

            let cell: TabItemView
            if let reused = tableView.makeView(withIdentifier: TabItemView.identifier, owner: self) as? TabItemView {
                cell = reused
            } else {
                cell = TabItemView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 28))
                cell.identifier = TabItemView.identifier
            }

            let isSelected = (tab.id == tabManager.activeTabId)
            cell.configure(with: tab, isSelected: isSelected)

            cell.onClose = { [weak self, weak tab] in
                guard let self = self, let tab = tab else { return }
                self.tabManager.closeTab(id: tab.id)
            }

            return cell
        } else {
            // "+ New tab" action row immediately following the last tab
            let cell: NewTabActionCellView
            if let reused = tableView.makeView(withIdentifier: NewTabActionCellView.identifier, owner: self) as? NewTabActionCellView {
                cell = reused
            } else {
                cell = NewTabActionCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 28))
                cell.identifier = NewTabActionCellView.identifier
            }

            cell.onClick = { [weak self] in
                self?.didClickNewTab()
            }

            return cell
        }
    }
}
