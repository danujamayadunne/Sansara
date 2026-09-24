import AppKit

private final class BorderSplitView: NSSplitView {
    override var dividerColor: NSColor {
        return .clear
    }
    override var dividerThickness: CGFloat {
        return 0.0
    }
    override func drawDivider(in rect: NSRect) {
        // No divider line drawn between sidebar and content
    }
}

/// Split view controller hosting the sidebar (white in light mode, matte black in dark mode) and browser content,
/// with seamless edge-to-edge transition.
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
        contentVC.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }

        // Initialize with default state
        sidebarVC.reloadData()
        contentVC.update(for: tabManager.activeTab)
        updateSidebarState()
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
        let willCollapse = !sidebarSplitItem.isCollapsed
        sidebarSplitItem.isCollapsed = willCollapse
        sidebarVC.view.isHidden = willCollapse
        updateSidebarState()
    }

    private func updateSidebarState() {
        let isCollapsed = sidebarSplitItem.isCollapsed || sidebarVC.view.frame.width <= 1.0 || sidebarVC.view.isHidden
        sidebarVC.view.isHidden = isCollapsed
        contentVC.setSidebarVisible(!isCollapsed)
    }

    public override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        updateSidebarState()
    }

    public override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return subview === sidebarVC.view
    }

    public override func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        return (sidebarSplitItem?.isCollapsed ?? false) || sidebarVC.view.isHidden
    }

    public override func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            if proposedPosition < 120 {
                return 0
            }
        }
        return proposedPosition
    }

    public func focusAddressBar() {
        contentVC.focusAddressBar()
    }

    // MARK: - TabManagerDelegate

    public func tabManager(_ manager: TabManager, didAddTab tab: BrowserTab, at index: Int) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.updateNavButtons()
        contentVC.update(for: manager.activeTab)
    }

    public func tabManager(_ manager: TabManager, didRemoveTab tab: BrowserTab, at index: Int) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.updateNavButtons()
        contentVC.update(for: manager.activeTab)
    }

    public func tabManager(_ manager: TabManager, didSelectTab tab: BrowserTab) {
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.updateNavButtons()
        contentVC.update(for: tab)
    }

    public func tabManager(_ manager: TabManager, didUpdateTab tab: BrowserTab) {
        if tab.id == tabManager.activeTabId {
            contentVC.update(for: tab)
        }
        sidebarVC.reloadData()
        sidebarVC.updateNavButtons()
        contentVC.updateNavButtons()
    }

    public func tabManagerDidUpdateGroups(_ manager: TabManager) {
        sidebarVC.reloadData()
        contentVC.reloadTabStripe()
    }
}
