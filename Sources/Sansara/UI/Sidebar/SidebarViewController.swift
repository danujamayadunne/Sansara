import AppKit

private final class SidebarTableView: NSTableView {
    var onMenuForTab: ((Int) -> NSMenu?)?
    var onMenuForEmptyArea: (() -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0 {
            return onMenuForTab?(row)
        }
        return onMenuForEmptyArea?() ?? super.menu(for: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        let menuToPop = (row >= 0 ? onMenuForTab?(row) : onMenuForEmptyArea?()) ?? self.menu(for: event)
        if let menu = menuToPop {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
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

/// Row view that eliminates system blue selection while providing clean drag feedback
private final class CleanTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {}

    override func drawDraggingDestinationFeedback(in dirtyRect: NSRect) {
        if draggingDestinationFeedbackStyle == .regular {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 7, yRadius: 7)
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.12).setFill()
            path.fill()
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.55).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        } else {
            super.drawDraggingDestinationFeedback(in: dirtyRect)
        }
    }
}

/// Cell representing the "+ New tab" action
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
        plusImageView.contentTintColor = .secondaryLabelColor
        plusImageView.translatesAutoresizingMaskIntoConstraints = false
        containerBox.addSubview(plusImageView)

        label.isEditable = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabelColor
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
        containerBox.fillColor = NSColor.quaternaryLabelColor
        label.textColor = .labelColor
        plusImageView.contentTintColor = .labelColor
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        containerBox.fillColor = .clear
        label.textColor = .secondaryLabelColor
        plusImageView.contentTintColor = .secondaryLabelColor
    }

    public override func mouseDown(with event: NSEvent) {
        containerBox.fillColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.3)
        onClick?()
    }

    public override func mouseUp(with event: NSEvent) {
        containerBox.fillColor = .clear
    }
}



/// Arc-style sidebar controller featuring pure white in light mode and matte black in dark mode.
public final class SidebarViewController: NSViewController {

    private enum SidebarItem {
        case tab(BrowserTab, isInsideGroup: Bool, groupColor: TabGroupColor?)
        case folder(TabGroup, tabCount: Int)
        case newTabAction
    }

    public let tabManager: TabManager
    public var onToggleSidebar: (() -> Void)?

    private var sidebarItems: [SidebarItem] = []
    private var lastAddTabTimestamp: TimeInterval = 0

    // Top navigation buttons
    private let navStack = NSStackView()
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!

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
        view = SidebarBackgroundView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        reloadData()
    }

    private func setupUI() {
        // Top navigation buttons: Back, Forward, Reload
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

        // Scroll view for tabs
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Dynamic top spacing respecting system titlebar area
            navStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
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
        button.contentTintColor = .secondaryLabelColor
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

    public func updateNavButtons() {
        let tab = tabManager.activeTab
        backButton.isEnabled = tab?.canGoBack ?? false
        forwardButton.isEnabled = tab?.canGoForward ?? false
        backButton.contentTintColor = backButton.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        forwardButton.contentTintColor = forwardButton.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
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
        tableView.doubleAction = #selector(didDoubleClickTableRow)

        tableView.onMenuForTab = { [weak self] row in
            self?.createContextMenu(for: row)
        }
        tableView.onMenuForEmptyArea = { [weak self] in
            self?.createEmptyAreaContextMenu()
        }

        tableView.registerForDraggedTypes([
            NSPasteboard.PasteboardType.string,
            NSPasteboard.PasteboardType("com.sansara.browser.tab")
        ])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)

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

    private func updateSidebarItems() {
        var items: [SidebarItem] = []
        var processedGroupIds = Set<UUID>()

        for tab in tabManager.tabs {
            if let groupId = tab.groupId, let group = tabManager.groups.first(where: { $0.id == groupId }) {
                if !processedGroupIds.contains(groupId) {
                    processedGroupIds.insert(groupId)
                    let groupTabs = tabManager.tabs.filter { $0.groupId == groupId }
                    items.append(.folder(group, tabCount: groupTabs.count))
                }
                if !group.isCollapsed {
                    items.append(.tab(tab, isInsideGroup: true, groupColor: group.color))
                }
            } else {
                items.append(.tab(tab, isInsideGroup: false, groupColor: nil))
            }
        }

        // Empty groups
        for group in tabManager.groups where !processedGroupIds.contains(group.id) {
            items.append(.folder(group, tabCount: 0))
        }

        items.append(.newTabAction)
        sidebarItems = items
    }

    public func reloadData() {
        updateSidebarItems()
        tableView.reloadData()
    }

    @objc private func didClickNewTab() {
        tabManager.createTab(url: nil, select: true)
    }

    @objc private func didClickNewFolder() {
        promptCreateFolder()
    }

    public func promptCreateFolder(initialTabId: UUID? = nil) {
        TabGroupDialog.show(title: "New Tab Folder", actionButtonTitle: "Create") { [weak self] name, color in
            guard let self = self, let name = name, let color = color else { return }
            let tabIds = initialTabId != nil ? [initialTabId!] : []
            self.tabManager.createGroup(name: name, color: color, tabIds: tabIds)
            self.reloadData()
        }
    }

    @objc private func didSelectTableRow() {
        if ProcessInfo.processInfo.systemUptime - lastAddTabTimestamp < 0.35 {
            return
        }
        if let event = NSApp.currentEvent {
            let pointInTable = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: pointInTable)
            if row >= 0, let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? FolderItemView {
                if cell.isPointInAddButton(event.locationInWindow) {
                    return
                }
            }
            if row >= 0, let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? TabItemView {
                if cell.isPointInCloseButton(event.locationInWindow) {
                    return
                }
            }
        }

        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < sidebarItems.count else { return }

        switch sidebarItems[clickedRow] {
        case .tab(let tab, _, _):
            tabManager.selectTab(id: tab.id)
        case .folder(let group, _):
            tabManager.toggleGroupCollapsed(id: group.id)
            reloadData()
        case .newTabAction:
            didClickNewTab()
        }
    }

    @objc private func didDoubleClickTableRow() {
        var row = tableView.clickedRow
        if row < 0, let event = NSApp.currentEvent {
            let point = tableView.convert(event.locationInWindow, from: nil)
            row = tableView.row(at: point)
        }
        guard row >= 0 && row < sidebarItems.count else { return }

        switch sidebarItems[row] {
        case .tab(let tab, _, _):
            startRenameTab(tab, at: row)
        case .folder(let group, _):
            promptRenameFolder(group)
        case .newTabAction:
            break
        }
    }

    private func createContextMenu(for row: Int) -> NSMenu? {
        guard row >= 0 && row < sidebarItems.count else { return createEmptyAreaContextMenu() }

        switch sidebarItems[row] {
        case .folder(let group, _):
            return createFolderContextMenu(for: group)
        case .tab(let tab, _, _):
            return createTabContextMenu(for: tab)
        case .newTabAction:
            return createEmptyAreaContextMenu()
        }
    }

    private func createEmptyAreaContextMenu() -> NSMenu {
        let menu = NSMenu()
        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(didClickNewTab), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

        let newFolderItem = NSMenuItem(title: "New Folder…", action: #selector(didClickNewFolder), keyEquivalent: "")
        newFolderItem.target = self
        menu.addItem(newFolderItem)

        if !tabManager.closedHistory.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let reopenItem = NSMenuItem(title: "Reopen Closed Tab", action: #selector(menuReopenClosedTab), keyEquivalent: "T")
            reopenItem.target = self
            menu.addItem(reopenItem)
        }
        return menu
    }

    @objc private func menuReopenClosedTab() {
        tabManager.reopenClosedTab()
    }

    public func createFolderContextMenu(for group: TabGroup) -> NSMenu {
        let menu = NSMenu()

        let newTabInFolder = NSMenuItem(title: "New Tab in Folder", action: #selector(menuAddTabToFolder(_:)), keyEquivalent: "")
        newTabInFolder.target = self
        newTabInFolder.representedObject = group
        menu.addItem(newTabInFolder)

        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(title: "Rename Folder…", action: #selector(menuRenameFolder(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = group
        menu.addItem(renameItem)

        // Change color submenu
        let colorMenuItem = NSMenuItem(title: "Change Color", action: nil, keyEquivalent: "")
        let colorSubmenu = NSMenu()
        for color in TabGroupColor.allCases {
            let item = NSMenuItem(title: color.rawValue, action: #selector(menuChangeFolderColor(_:)), keyEquivalent: "")
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

        let ungroupItem = NSMenuItem(title: "Ungroup Folder", action: #selector(menuUngroupFolder(_:)), keyEquivalent: "")
        ungroupItem.target = self
        ungroupItem.representedObject = group
        menu.addItem(ungroupItem)

        let closeFolderItem = NSMenuItem(title: "Close Folder", action: #selector(menuCloseFolder(_:)), keyEquivalent: "")
        closeFolderItem.target = self
        closeFolderItem.representedObject = group
        menu.addItem(closeFolderItem)

        return menu
    }

    public func createTabContextMenu(for tab: BrowserTab) -> NSMenu {
        let menu = NSMenu()

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(didClickNewTab), keyEquivalent: "t")
        newTabItem.target = self
        menu.addItem(newTabItem)

        menu.addItem(NSMenuItem.separator())

        // Tab Grouping actions
        let renameTabItem = NSMenuItem(title: "Rename Tab…", action: #selector(menuRenameTab(_:)), keyEquivalent: "")
        renameTabItem.target = self
        renameTabItem.representedObject = tab
        menu.addItem(renameTabItem)

        let newFolderWithTab = NSMenuItem(title: "New Folder with Tab…", action: #selector(menuNewFolderWithTab(_:)), keyEquivalent: "")
        newFolderWithTab.target = self
        newFolderWithTab.representedObject = tab
        menu.addItem(newFolderWithTab)

        let moveToFolderItem = NSMenuItem(title: "Move to Folder", action: nil, keyEquivalent: "")
        let folderSubmenu = NSMenu()

        if !tabManager.groups.isEmpty {
            for group in tabManager.groups {
                let item = NSMenuItem(title: group.name, action: #selector(menuMoveTabToGroup(_:)), keyEquivalent: "")
                item.target = self
                item.image = group.color.circleImage(size: 12)
                item.representedObject = (tab, group)
                if tab.groupId == group.id {
                    item.state = .on
                }
                folderSubmenu.addItem(item)
            }
            if tab.groupId != nil {
                folderSubmenu.addItem(NSMenuItem.separator())
                let removeItem = NSMenuItem(title: "Remove from Folder", action: #selector(menuRemoveTabFromFolder(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = tab
                folderSubmenu.addItem(removeItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: "No Folders", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            folderSubmenu.addItem(emptyItem)
        }
        moveToFolderItem.submenu = folderSubmenu
        menu.addItem(moveToFolderItem)

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

    // MARK: - Context Menu Handlers

    @objc private func menuAddTabToFolder(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.createTab(inGroup: group.id, select: true)
    }

    public func promptRenameFolder(_ group: TabGroup) {
        TabGroupDialog.promptRename(currentName: group.name) { [weak self] newName in
            guard let self = self, let newName = newName else { return }
            self.tabManager.renameGroup(id: group.id, newName: newName)
            self.reloadData()
        }
    }

    public func startRenameTab(_ tab: BrowserTab, at row: Int? = nil) {
        let targetRow: Int? = row ?? sidebarItems.firstIndex(where: {
            if case .tab(let t, _, _) = $0 { return t.id == tab.id }
            return false
        })
        if let r = targetRow, r >= 0 && r < sidebarItems.count,
           let cell = tableView.view(atColumn: 0, row: r, makeIfNecessary: true) as? TabItemView {
            cell.startEditing()
            return
        }
        promptRenameTab(tab)
    }

    public func promptRenameTab(_ tab: BrowserTab) {
        TabGroupDialog.promptRenameTab(currentName: tab.title) { [weak self] newTitle in
            guard let self = self, let newTitle = newTitle else { return }
            tab.rename(to: newTitle)
            self.reloadData()
        }
    }

    @objc private func menuRenameFolder(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        promptRenameFolder(group)
    }

    @objc private func menuRenameTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        startRenameTab(tab)
    }

    @objc private func menuChangeFolderColor(_ sender: NSMenuItem) {
        guard let tuple = sender.representedObject as? (TabGroup, TabGroupColor) else { return }
        tabManager.setGroupColor(id: tuple.0.id, color: tuple.1)
        reloadData()
    }

    @objc private func menuUngroupFolder(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.ungroup(groupId: group.id)
        reloadData()
    }

    @objc private func menuCloseFolder(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? TabGroup else { return }
        tabManager.closeGroup(groupId: group.id)
        reloadData()
    }

    @objc private func menuNewFolderWithTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        promptCreateFolder(initialTabId: tab.id)
    }

    @objc private func menuMoveTabToGroup(_ sender: NSMenuItem) {
        guard let tuple = sender.representedObject as? (BrowserTab, TabGroup) else { return }
        tabManager.addTabs([tuple.0.id], to: tuple.1.id)
        reloadData()
    }

    @objc private func menuRemoveTabFromFolder(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? BrowserTab else { return }
        tabManager.removeTabFromGroup(id: tab.id)
        reloadData()
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
        return sidebarItems.count
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CleanTableRowView()
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0 && row < sidebarItems.count else { return 28 }
        switch sidebarItems[row] {
        case .folder:
            return 30
        case .tab:
            return 28
        case .newTabAction:
            return 26
        }
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < sidebarItems.count else { return nil }

        switch sidebarItems[row] {
        case .folder(let group, let count):
            let cell: FolderItemView
            if let reused = tableView.makeView(withIdentifier: FolderItemView.identifier, owner: self) as? FolderItemView {
                cell = reused
            } else {
                cell = FolderItemView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 30))
                cell.identifier = FolderItemView.identifier
            }

            cell.configure(with: group, tabCount: count)
            cell.onToggleCollapse = { [weak self, weak group] in
                guard let self = self, let group = group else { return }
                self.tabManager.toggleGroupCollapsed(id: group.id)
                self.reloadData()
            }
            cell.onDoubleClick = { [weak self, weak group] in
                guard let self = self, let group = group else { return }
                self.promptRenameFolder(group)
            }
            cell.onAddTab = { [weak self, weak group] in
                guard let self = self, let group = group else { return }
                self.lastAddTabTimestamp = ProcessInfo.processInfo.systemUptime
                self.tabManager.createTab(inGroup: group.id, select: true)
                self.reloadData()
            }
            cell.onContextMenu = { [weak self, weak group] in
                guard let self = self, let group = group else { return nil }
                return self.createFolderContextMenu(for: group)
            }
            return cell

        case .tab(let tab, let isInsideGroup, let groupColor):
            let cell: TabItemView
            if let reused = tableView.makeView(withIdentifier: TabItemView.identifier, owner: self) as? TabItemView {
                cell = reused
            } else {
                cell = TabItemView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 28))
                cell.identifier = TabItemView.identifier
            }

            let isSelected = (tab.id == tabManager.activeTabId)
            cell.configure(with: tab, isSelected: isSelected, isInsideGroup: isInsideGroup, groupColor: groupColor)

            cell.onDoubleClick = { [weak cell] in
                cell?.startEditing()
            }
            cell.onClose = { [weak self, weak tab] in
                guard let self = self, let tab = tab else { return }
                self.tabManager.closeTab(id: tab.id)
            }
            cell.onContextMenu = { [weak self, weak tab] in
                guard let self = self, let tab = tab else { return nil }
                return self.createTabContextMenu(for: tab)
            }
            return cell

        case .newTabAction:
            let cell: NewTabActionCellView
            if let reused = tableView.makeView(withIdentifier: NewTabActionCellView.identifier, owner: self) as? NewTabActionCellView {
                cell = reused
            } else {
                cell = NewTabActionCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 26))
                cell.identifier = NewTabActionCellView.identifier
            }
            cell.onClick = { [weak self] in
                self?.didClickNewTab()
            }
            return cell
        }
    }

    // MARK: - Drag and Drop (Tab to Folder & Tab Reordering)

    public func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row >= 0 && row < sidebarItems.count else { return nil }
        switch sidebarItems[row] {
        case .tab(let tab, _, _):
            let item = NSPasteboardItem()
            item.setString(tab.id.uuidString, forType: NSPasteboard.PasteboardType("com.sansara.browser.tab"))
            item.setString(tab.id.uuidString, forType: .string)
            return item
        case .folder, .newTabAction:
            return nil
        }
    }

    public func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard let pboard = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType("com.sansara.browser.tab")) ?? info.draggingPasteboard.string(forType: .string),
              UUID(uuidString: pboard) != nil else {
            return []
        }

        if row >= 0 && row < sidebarItems.count {
            switch sidebarItems[row] {
            case .folder:
                return .move
            case .tab:
                return .move
            case .newTabAction:
                return dropOperation == .above ? .move : []
            }
        } else if row == sidebarItems.count {
            return .move
        }

        return []
    }

    public func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let str = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType("com.sansara.browser.tab")) ?? info.draggingPasteboard.string(forType: .string),
              let draggedTabId = UUID(uuidString: str) else {
            return false
        }

        // Dropping directly ON a row
        if dropOperation == .on && row >= 0 && row < sidebarItems.count {
            if case .folder(let group, _) = sidebarItems[row] {
                // Drop tab onto a folder -> adds tab to folder
                tabManager.addTabs([draggedTabId], to: group.id)
                group.isCollapsed = false
                reloadData()
                return true
            } else if case .tab(let targetTab, _, _) = sidebarItems[row] {
                guard draggedTabId != targetTab.id else { return false }
                if let targetGroupId = targetTab.groupId {
                    tabManager.addTabs([draggedTabId], to: targetGroupId)
                    tabManager.moveTab(id: draggedTabId, beforeOrAfter: targetTab.id, placeAfter: true)
                } else {
                    // Auto-create folder with default blue containing both targetTab and draggedTab
                    let newGroup = tabManager.createGroup(name: "New Folder", color: .blue, tabIds: [targetTab.id, draggedTabId])
                    newGroup.isCollapsed = false
                }
                reloadData()
                return true
            }
        }

        // Dropping ABOVE or between rows
        if row >= 0 && row < sidebarItems.count {
            switch sidebarItems[row] {
            case .folder(let group, _):
                // Dropped right above a folder header: place ungrouped before this folder
                tabManager.removeTabFromGroup(id: draggedTabId)
                if let firstTab = tabManager.tabs.first(where: { $0.groupId == group.id }) {
                    tabManager.moveTab(id: draggedTabId, beforeOrAfter: firstTab.id, placeAfter: false)
                }
                reloadData()
                return true

            case .tab(let targetTab, let isInsideGroup, _):
                if isInsideGroup, let groupId = targetTab.groupId {
                    tabManager.addTabs([draggedTabId], to: groupId)
                } else {
                    tabManager.removeTabFromGroup(id: draggedTabId)
                }
                tabManager.moveTab(id: draggedTabId, beforeOrAfter: targetTab.id, placeAfter: false)
                reloadData()
                return true

            case .newTabAction:
                tabManager.removeTabFromGroup(id: draggedTabId)
                tabManager.moveTabToEnd(id: draggedTabId)
                reloadData()
                return true
            }
        } else {
            tabManager.removeTabFromGroup(id: draggedTabId)
            tabManager.moveTabToEnd(id: draggedTabId)
            reloadData()
            return true
        }
    }
}
