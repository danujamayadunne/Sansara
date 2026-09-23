import AppKit

private final class BorderSplitView: NSSplitView {
    override var dividerColor: NSColor {
        return NSColor(white: 0.92, alpha: 1.0)
    }
    override var dividerThickness: CGFloat {
        return 1.0
    }
}

/// Split view controller hosting the pure-white sidebar and browser content,
/// separated by a crisp 1px vertical border.
public final class BrowserSplitViewController: NSSplitViewController, TabManagerDelegate {

    public let tabManager: TabManager
    public let sidebarVC: SidebarViewController
    public let contentVC: BrowserContentViewController

    private var sidebarSplitItem: NSSplitViewItem!
    private var contentSplitItem: NSSplitViewItem!

    public init(tabManager: TabManager) {
        self.tabManager = tabManager
        self.sidebarVC = SidebarViewController(tabManager: tabManager)
        self.contentVC = BrowserContentViewController(tabManager: tabManager)
        super.init(nibName: nil, bundle: nil)
        self.tabManager.delegate = self
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        splitView = BorderSplitView()
        super.loadView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSplitView()
        setupSplitItems()

        sidebarVC.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }

        // Initialize with default state
        sidebarVC.reloadData()
        contentVC.update(for: tabManager.activeTab)
    }

    private func setupSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
    }

    private func setupSplitItems() {
        sidebarSplitItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarSplitItem.minimumThickness = 240
        sidebarSplitItem.maximumThickness = 320
        sidebarSplitItem.preferredThicknessFraction = 0.235
        sidebarSplitItem.canCollapse = true
        sidebarSplitItem.holdingPriority = .defaultHigh

        contentSplitItem = NSSplitViewItem(viewController: contentVC)
        contentSplitItem.holdingPriority = .defaultLow

        addSplitViewItem(sidebarSplitItem)
        addSplitViewItem(contentSplitItem)
    }

    public func toggleSidebar() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            sidebarSplitItem.animator().isCollapsed.toggle()
        }, completionHandler: { [weak self] in
            self?.updateSidebarState()
        })
    }

    private func updateSidebarState() {
        contentVC.setSidebarVisible(!sidebarSplitItem.isCollapsed)
    }

    public override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        updateSidebarState()
    }

    public func focusAddressBar() {
        contentVC.focusAddressBar()
    }

    // MARK: - TabManagerDelegate

    public func tabManager(_ manager: TabManager, didAddTab tab: BrowserTab, at index: Int) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.update(for: manager.activeTab)
    }

    public func tabManager(_ manager: TabManager, didRemoveTab tab: BrowserTab, at index: Int) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.update(for: manager.activeTab)
    }

    public func tabManager(_ manager: TabManager, didSelectTab tab: BrowserTab) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.update(for: tab)
    }

    public func tabManager(_ manager: TabManager, didUpdateTab tab: BrowserTab) {
        if tab.id == tabManager.activeTabId {
            contentVC.update(for: tab)
        }
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
    }
}
