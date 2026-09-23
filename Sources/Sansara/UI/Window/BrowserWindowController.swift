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
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor.white
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
}
