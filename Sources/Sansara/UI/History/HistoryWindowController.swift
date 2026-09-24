import AppKit

public final class HistoryItemCellView: NSTableCellView {
    public static let identifier = NSUserInterfaceItemIdentifier("HistoryItemCellViewIdentifier")

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")

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

        let clockImg = NSImage(systemSymbolName: "clock", accessibilityDescription: "History")
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        iconView.image = clockImg?.withSymbolConfiguration(config)
        iconView.contentTintColor = .secondaryLabelColor
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

        timeLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
        timeLabel.cell?.wraps = false
        timeLabel.cell?.isScrollable = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -12),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            urlLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -12),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }

    public func configure(with item: HistoryItem) {
        titleLabel.stringValue = item.title
        urlLabel.stringValue = item.url.absoluteString

        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(item.visitDate) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(item.visitDate) {
            formatter.dateFormat = "'Yesterday', h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        timeLabel.stringValue = formatter.string(from: item.visitDate)
    }
}

public final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    public var onOpenURL: ((URL) -> Void)?
    public var onOpenURLInNewTab: ((URL) -> Void)?

    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private let clearButton = NSButton(title: "Clear History…", target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var displayedItems: [HistoryItem] = []

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.minSize = NSSize(width: 500, height: 350)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        setupUI()
        reloadHistory()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidUpdate),
            name: HistoryManager.didUpdateNotification,
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

        searchField.placeholderString = "Search History"
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

        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearHistoryClicked)
        topBar.addArrangedSubview(clearButton)

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

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
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
        menu.addItem(NSMenuItem(title: "Copy Link", action: #selector(menuCopyLink), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Delete Entry", action: #selector(menuDeleteSelected), keyEquivalent: ""))
        return menu
    }

    public func reloadHistory() {
        let query = searchField.stringValue
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayedItems = HistoryManager.shared.allHistory()
        } else {
            displayedItems = HistoryManager.shared.search(query: query)
        }
        countLabel.stringValue = "\(displayedItems.count) item\(displayedItems.count == 1 ? "" : "s")"
        tableView.reloadData()
    }

    @objc private func historyDidUpdate() {
        reloadHistory()
    }

    @objc private func searchChanged() {
        reloadHistory()
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
        HistoryManager.shared.deleteItem(id: item.id)
    }

    @objc private func clearHistoryClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear All Browsing History?"
        alert.informativeText = "Are you sure you want to clear your browsing history? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearAll()
            FaviconService.shared.clearCache()
        }
    }

    // MARK: - NSTableViewDataSource & NSTableViewDelegate

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedItems.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < displayedItems.count else { return nil }
        let item = displayedItems[row]

        let cell: HistoryItemCellView
        if let reused = tableView.makeView(withIdentifier: HistoryItemCellView.identifier, owner: self) as? HistoryItemCellView {
            cell = reused
        } else {
            cell = HistoryItemCellView()
            cell.identifier = HistoryItemCellView.identifier
        }
        cell.configure(with: item)
        return cell
    }
}
