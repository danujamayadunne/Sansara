import Foundation
import AppKit

public struct ClosedTabRecord {
    public let url: URL?
    public let title: String
}

public protocol TabManagerDelegate: AnyObject {
    func tabManager(_ manager: TabManager, didAddTab tab: BrowserTab, at index: Int)
    func tabManager(_ manager: TabManager, didRemoveTab tab: BrowserTab, at index: Int)
    func tabManager(_ manager: TabManager, didSelectTab tab: BrowserTab)
    func tabManager(_ manager: TabManager, didUpdateTab tab: BrowserTab)
}

/// Central tab manager that controls tab lifecycle, tab history, and active tab state.
public final class TabManager: NSObject, BrowserTabDelegate {

    public weak var delegate: TabManagerDelegate?

    public private(set) var tabs: [BrowserTab] = []
    public private(set) var activeTabId: UUID?
    public private(set) var closedHistory: [ClosedTabRecord] = []

    public var activeTab: BrowserTab? {
        guard let id = activeTabId else { return nil }
        return tabs.first(where: { $0.id == id })
    }

    public var activeTabIndex: Int? {
        guard let id = activeTabId else { return nil }
        return tabs.firstIndex(where: { $0.id == id })
    }

    public override init() {
        super.init()
    }

    // MARK: - Tab Creation & Removal

    @discardableResult
    public func createTab(
        url: URL? = nil,
        select: Bool = true,
        insertAfterActive: Bool = false
    ) -> BrowserTab {
        let newTab = BrowserTab(initialURL: url)
        newTab.delegate = self

        var targetIndex = tabs.count
        if insertAfterActive, let currentIndex = activeTabIndex {
            targetIndex = currentIndex + 1
            tabs.insert(newTab, at: targetIndex)
        } else {
            tabs.append(newTab)
        }

        delegate?.tabManager(self, didAddTab: newTab, at: targetIndex)

        if select {
            selectTab(id: newTab.id)
        }

        return newTab
    }

    public func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tabToClose = tabs[index]

        // Record in closed history if it had a URL
        if let url = tabToClose.url {
            closedHistory.append(ClosedTabRecord(url: url, title: tabToClose.title))
            if closedHistory.count > 25 {
                closedHistory.removeFirst()
            }
        }

        let wasActive = (activeTabId == id)

        // Select fallback tab if this was active
        var nextActiveId: UUID?
        if wasActive {
            if tabs.count > 1 {
                if index + 1 < tabs.count {
                    nextActiveId = tabs[index + 1].id
                } else if index - 1 >= 0 {
                    nextActiveId = tabs[index - 1].id
                }
            }
        }

        tabToClose.cleanup()
        tabs.remove(at: index)
        delegate?.tabManager(self, didRemoveTab: tabToClose, at: index)

        if wasActive {
            if let nextId = nextActiveId {
                selectTab(id: nextId)
            } else {
                // If all tabs were closed, create a fresh empty new tab
                createTab(url: nil, select: true)
            }
        }
    }

    public func closeOtherTabs(except id: UUID) {
        let otherTabs = tabs.filter { $0.id != id }
        for tab in otherTabs {
            closeTab(id: tab.id)
        }
        selectTab(id: id)
    }

    public func duplicateTab(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        createTab(url: tab.url, select: true, insertAfterActive: true)
    }

    public func reopenClosedTab() {
        guard let lastClosed = closedHistory.popLast() else { return }
        createTab(url: lastClosed.url, select: true)
    }

    // MARK: - Tab Selection

    public func selectTab(id: UUID) {
        guard activeTabId != id else { return }
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        activeTabId = id
        delegate?.tabManager(self, didSelectTab: tab)
    }

    public func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectTab(id: tabs[index].id)
    }

    public func selectNextTab() {
        guard !tabs.isEmpty, let currentIndex = activeTabIndex else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        selectTab(at: nextIndex)
    }

    public func selectPreviousTab() {
        guard !tabs.isEmpty, let currentIndex = activeTabIndex else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        selectTab(at: prevIndex)
    }

    // MARK: - BrowserTabDelegate

    public func browserTabDidUpdate(_ tab: BrowserTab) {
        delegate?.tabManager(self, didUpdateTab: tab)
    }

    public func browserTab(_ tab: BrowserTab, requestOpenNewTabWith request: URLRequest) {
        createTab(url: request.url, select: true, insertAfterActive: true)
    }
}
