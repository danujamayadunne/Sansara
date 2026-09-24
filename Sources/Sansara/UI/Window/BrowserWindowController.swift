import AppKit

/// Window controller for the main browser window.
public final class BrowserWindowController: NSWindowController, NSWindowDelegate {

    public let tabManager: TabManager
    public let splitViewController: BrowserSplitViewController

    public init(tabManager: TabManager = TabManager()) {
        self.tabManager = tabManager
        self.splitViewController = BrowserSplitViewController(tabManager: tabManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Sansara"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.appearance = nil // Automatically adapts to Light/Dark Mode
        window.backgroundColor = ContentColors.dynamicBackground
        window.center()

        super.init(window: window)

        window.delegate = self
        window.contentViewController = splitViewController

        // Ensure an initial tab exists
        if tabManager.tabs.isEmpty {
            tabManager.createTab(url: nil, select: true)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Actions

    public func newTab() {
        tabManager.createTab(url: nil, select: true)
    }

    public func closeCurrentTab() {
        if let activeId = tabManager.activeTabId {
            tabManager.closeTab(id: activeId)
        }
    }

    public func reopenClosedTab() {
        tabManager.reopenClosedTab()
    }

    public func focusAddressBar() {
        splitViewController.focusAddressBar()
    }

    public func reloadCurrentPage() {
        tabManager.activeTab?.reload()
    }

    public func navigateBack() {
        tabManager.activeTab?.goBack()
    }

    public func navigateForward() {
        tabManager.activeTab?.goForward()
    }

    public func selectTab(at index: Int) {
        tabManager.selectTab(at: index)
    }

    public func toggleSidebar() {
        splitViewController.toggleSidebar()
    }

    // MARK: - Auxiliary Windows & Management

    private var settingsWindowController: SettingsWindowController?
    private var historyWindowController: HistoryWindowController?
    private var bookmarksWindowController: BookmarksWindowController?

    public func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(self)
        settingsWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showHistory() {
        if historyWindowController == nil {
            let controller = HistoryWindowController()
            controller.onOpenURL = { [weak self] url in
                self?.openURL(url, inNewTab: false)
            }
            controller.onOpenURLInNewTab = { [weak self] url in
                self?.openURL(url, inNewTab: true)
            }
            historyWindowController = controller
        }
        historyWindowController?.reloadHistory()
        historyWindowController?.showWindow(self)
        historyWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showBookmarks() {
        if bookmarksWindowController == nil {
            let controller = BookmarksWindowController()
            controller.onOpenURL = { [weak self] url in
                self?.openURL(url, inNewTab: false)
            }
            controller.onOpenURLInNewTab = { [weak self] url in
                self?.openURL(url, inNewTab: true)
            }
            bookmarksWindowController = controller
        }
        bookmarksWindowController?.reloadBookmarks()
        bookmarksWindowController?.showWindow(self)
        bookmarksWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func toggleBookmarkForCurrentTab() {
        guard let tab = tabManager.activeTab, let url = tab.url else { return }
        BookmarkManager.shared.toggleBookmark(title: tab.title, url: url)
    }

    public func openURL(_ url: URL, inNewTab: Bool = false) {
        if inNewTab || tabManager.activeTab == nil {
            tabManager.createTab(url: url, select: true)
        } else {
            tabManager.activeTab?.load(url: url)
        }
    }

    public func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Browsing History?"
        alert.informativeText = "Are you sure you want to clear your browsing history? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearAll()
            FaviconService.shared.clearCache()
        }
    }
}
