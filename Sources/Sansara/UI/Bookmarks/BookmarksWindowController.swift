import AppKit

public final class BookmarkItemCellView: NSTableCellView {
    public static let identifier = NSUserInterfaceItemIdentifier("BookmarkItemCellViewIdentifier")

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private let folderBadge = NSTextField(labelWithString: "")

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        let starImg = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Bookmark")
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iconView.image = starImg?.withSymbolConfiguration(config)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        urlLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.cell?.wraps = false
        urlLabel.cell?.isScrollable = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(urlLabel)

        folderBadge.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        folderBadge.textColor = .secondaryLabelColor
        folderBadge.alignment = .right
        folderBadge.cell?.wraps = false
        folderBadge.cell?.isScrollable = false
        folderBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(folderBadge)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: folderBadge.leadingAnchor, constant: -12),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            urlLabel.trailingAnchor.constraint(lessThanOrEqualTo: folderBadge.leadingAnchor, constant: -12),

            folderBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            folderBadge.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    public func configure(with item: BookmarkItem) {
        titleLabel.stringValue = item.title
        urlLabel.stringValue = item.url.absoluteString
        folderBadge.stringValue = item.folder ?? ""
    }
}

public final class BookmarksWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    public var onOpenURL: ((URL) -> Void)?
    public var onOpenURLInNewTab: ((URL) -> Void)?

    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private let addBookmarkButton = NSButton(title: "+ Add Bookmark…", target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var displayedItems: [BookmarkItem] = []

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bookmarks"
        window.minSize = NSSize(width: 500, height: 350)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        setupUI()
        reloadBookmarks()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarksDidUpdate),
            name: BookmarkManager.didUpdateNotification,
            object: nil
        )
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Top Control Bar
        let topBar = NSStackView()
        topBar.orientation = .horizontal
        topBar.spacing = 12
        topBar.alignment = .centerY
        topBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(topBar)

        searchField.placeholderString = "Search Bookmarks"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        topBar.addArrangedSubview(searchField)

        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        topBar.addArrangedSubview(countLabel)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topBar.addArrangedSubview(spacer)

        addBookmarkButton.bezelStyle = .rounded
        addBookmarkButton.target = self
        addBookmarkButton.action = #selector(addBookmarkClicked)
        topBar.addArrangedSubview(addBookmarkButton)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        // Scroll View & Table View
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 44
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableRowDoubleClicked)
        tableView.menu = createContextMenu()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("BookmarksColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            topBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            topBar.heightAnchor.constraint(equalToConstant: 30),

            searchField.widthAnchor.constraint(equalToConstant: 240),

            separator.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open in Current Tab", action: #selector(menuOpenInCurrentTab), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open in New Tab", action: #selector(menuOpenInNewTab), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Edit Bookmark…", action: #selector(menuEditBookmark), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Link", action: #selector(menuCopyLink), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Delete Bookmark", action: #selector(menuDeleteSelected), keyEquivalent: ""))
        return menu
    }

    public func reloadBookmarks() {
        let query = searchField.stringValue
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayedItems = BookmarkManager.shared.allBookmarks()
        } else {
            displayedItems = BookmarkManager.shared.search(query: query)
        }
        countLabel.stringValue = "\(displayedItems.count) bookmark\(displayedItems.count == 1 ? "" : "s")"
        tableView.reloadData()
    }

    @objc private func bookmarksDidUpdate() {
        reloadBookmarks()
    }

    @objc private func searchChanged() {
        reloadBookmarks()
    }

    @objc private func tableRowDoubleClicked() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        let item = displayedItems[row]
        onOpenURL?(item.url)
    }

    @objc private func menuOpenInCurrentTab() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        onOpenURL?(displayedItems[row].url)
    }

    @objc private func menuOpenInNewTab() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        onOpenURLInNewTab?(displayedItems[row].url)
    }

    @objc private func menuCopyLink() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(displayedItems[row].url.absoluteString, forType: .string)
    }

    @objc private func menuDeleteSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        let item = displayedItems[row]
        BookmarkManager.shared.removeBookmark(id: item.id)
    }

    @objc private func menuEditBookmark() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < displayedItems.count else { return }
        let item = displayedItems[row]

        let alert = NSAlert()
        alert.messageText = "Edit Bookmark"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        stack.orientation = .vertical
        stack.spacing = 8

        let titleInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        titleInput.stringValue = item.title
        titleInput.placeholderString = "Title"

        let urlInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        urlInput.stringValue = item.url.absoluteString
        urlInput.placeholderString = "URL"

        stack.addArrangedSubview(titleInput)
        stack.addArrangedSubview(urlInput)
        alert.accessoryView = stack

        if alert.runModal() == .alertFirstButtonReturn {
            let newTitle = titleInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newURLStr = urlInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let validURL = URL(string: newURLStr) {
                BookmarkManager.shared.updateBookmark(id: item.id, title: newTitle.isEmpty ? item.title : newTitle, url: validURL, folder: item.folder)
            }
        }
    }

    @objc private func addBookmarkClicked() {
        let alert = NSAlert()
        alert.messageText = "Add Bookmark"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        stack.orientation = .vertical
        stack.spacing = 8

        let titleInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        titleInput.placeholderString = "Bookmark Title"

        let urlInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        urlInput.placeholderString = "https://example.com"

        stack.addArrangedSubview(titleInput)
        stack.addArrangedSubview(urlInput)
        alert.accessoryView = stack

        if alert.runModal() == .alertFirstButtonReturn {
            let title = titleInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let urlStr = urlInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlStr.isEmpty {
                let resolved = URLHelper.resolve(input: urlStr)
                BookmarkManager.shared.addBookmark(title: title.isEmpty ? (resolved.host ?? urlStr) : title, url: resolved)
            }
        }
    }

    // MARK: - NSTableViewDataSource & NSTableViewDelegate

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedItems.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < displayedItems.count else { return nil }
        let item = displayedItems[row]

        let cell: BookmarkItemCellView
        if let reused = tableView.makeView(withIdentifier: BookmarkItemCellView.identifier, owner: self) as? BookmarkItemCellView {
            cell = reused
        } else {
            cell = BookmarkItemCellView()
            cell.identifier = BookmarkItemCellView.identifier
        }
        cell.configure(with: item)
        return cell
    }
}
