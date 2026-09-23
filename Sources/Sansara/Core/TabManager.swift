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
    func tabManagerDidUpdateGroups(_ manager: TabManager)
}

public extension TabManagerDelegate {
    func tabManagerDidUpdateGroups(_ manager: TabManager) {}
}

/// Central tab manager that controls tab lifecycle, tab history, active tab state,
/// and tab groups / folders.
public final class TabManager: NSObject, BrowserTabDelegate {

    public weak var delegate: TabManagerDelegate?

    public private(set) var tabs: [BrowserTab] = []
    public private(set) var groups: [TabGroup] = []
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
        inGroup groupId: UUID? = nil,
        select: Bool = true,
        insertAfterActive: Bool = false
    ) -> BrowserTab {
        let newTab = BrowserTab(initialURL: url, groupId: groupId)
        newTab.delegate = self

        var targetIndex = tabs.count
        if let groupId = groupId {
            // If inside a group, place after the last tab of that group
            if let lastGroupIndex = tabs.lastIndex(where: { $0.groupId == groupId }) {
                targetIndex = lastGroupIndex + 1
            } else if insertAfterActive, let currentIndex = activeTabIndex {
                targetIndex = currentIndex + 1
            }
            // Auto expand the group when adding a tab into it
            if let group = groups.first(where: { $0.id == groupId }) {
                group.isCollapsed = false
            }
            tabs.insert(newTab, at: targetIndex)
        } else if insertAfterActive, let currentIndex = activeTabIndex {
            targetIndex = currentIndex + 1
            tabs.insert(newTab, at: targetIndex)
        } else {
            tabs.append(newTab)
        }

        delegate?.tabManager(self, didAddTab: newTab, at: targetIndex)
        if groupId != nil {
            delegate?.tabManagerDidUpdateGroups(self)
        }

        if select {
            selectTab(id: newTab.id)
        }

        // Apple Silicon Memory Guard: Automatically suspend older background tabs if count exceeds 15
        suspendInactiveTabs(maxActiveTabs: 15)

        return newTab
    }

    /// Apple Silicon Tab Nap: Suspends background tabs when total active count exceeds threshold
    public func suspendInactiveTabs(maxActiveTabs: Int = 10) {
        guard tabs.count > maxActiveTabs else { return }
        let backgroundTabs = tabs.filter { $0.id != activeTabId && !$0.isSuspended && $0.hasInstantiatedWebView }
        let excessCount = max(0, backgroundTabs.count - (maxActiveTabs - 1))
        for tab in backgroundTabs.prefix(excessCount) {
            tab.suspend()
        }
    }

    public func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tabToClose = tabs[index]
        let tabGroupId = tabToClose.groupId

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

        if tabGroupId != nil {
            delegate?.tabManagerDidUpdateGroups(self)
        }

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
        createTab(url: tab.url, inGroup: tab.groupId, select: true, insertAfterActive: true)
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

        // Wake tab if it was suspended under memory pressure
        tab.wakeIfNeeded()

        // Auto-expand group if tab is inside a collapsed group
        if let groupId = tab.groupId, let group = groups.first(where: { $0.id == groupId }), group.isCollapsed {
            group.isCollapsed = false
            delegate?.tabManagerDidUpdateGroups(self)
        }

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

    // MARK: - Group & Folder Management

    @discardableResult
    public func createGroup(
        name: String,
        color: TabGroupColor = .blue,
        tabIds: [UUID] = []
    ) -> TabGroup {
        let group = TabGroup(name: name, color: color)
        groups.append(group)
        if !tabIds.isEmpty {
            addTabs(tabIds, to: group.id)
        } else {
            delegate?.tabManagerDidUpdateGroups(self)
        }
        return group
    }

    public func renameGroup(id: UUID, newName: String) {
        guard let group = groups.first(where: { $0.id == id }) else { return }
        group.name = newName
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func setGroupColor(id: UUID, color: TabGroupColor) {
        guard let group = groups.first(where: { $0.id == id }) else { return }
        group.color = color
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func toggleGroupCollapsed(id: UUID) {
        guard let group = groups.first(where: { $0.id == id }) else { return }
        group.isCollapsed.toggle()
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func setGroupCollapsed(id: UUID, isCollapsed: Bool) {
        guard let group = groups.first(where: { $0.id == id }) else { return }
        group.isCollapsed = isCollapsed
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func addTabs(_ tabIds: [UUID], to groupId: UUID) {
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        for tabId in tabIds {
            if let tab = tabs.first(where: { $0.id == tabId }) {
                tab.groupId = group.id
            }
        }
        clusterGroupTabs(groupId: groupId)
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func removeTabFromGroup(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.groupId = nil
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func ungroup(groupId: UUID) {
        for tab in tabs where tab.groupId == groupId {
            tab.groupId = nil
        }
        groups.removeAll(where: { $0.id == groupId })
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func closeGroup(groupId: UUID) {
        let groupTabs = tabs.filter { $0.groupId == groupId }
        for tab in groupTabs {
            closeTab(id: tab.id)
        }
        groups.removeAll(where: { $0.id == groupId })
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func deleteGroup(id: UUID) {
        for tab in tabs where tab.groupId == id {
            tab.groupId = nil
        }
        groups.removeAll(where: { $0.id == id })
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func moveTab(id: UUID, beforeOrAfter targetId: UUID, placeAfter: Bool) {
        guard id != targetId,
              let fromIndex = tabs.firstIndex(where: { $0.id == id }),
              let toIndex = tabs.firstIndex(where: { $0.id == targetId }) else { return }

        let tab = tabs.remove(at: fromIndex)
        let newTargetIndex = tabs.firstIndex(where: { $0.id == targetId }) ?? toIndex
        let insertIndex = placeAfter ? min(newTargetIndex + 1, tabs.count) : newTargetIndex
        tabs.insert(tab, at: insertIndex)

        if let groupId = tab.groupId {
            clusterGroupTabs(groupId: groupId)
        }
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func moveTabToEnd(id: UUID) {
        guard let fromIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs.remove(at: fromIndex)
        tabs.append(tab)
        if let groupId = tab.groupId {
            clusterGroupTabs(groupId: groupId)
        }
        delegate?.tabManagerDidUpdateGroups(self)
    }

    public func group(for id: UUID) -> TabGroup? {
        return groups.first(where: { $0.id == id })
    }

    public func tabs(for groupId: UUID) -> [BrowserTab] {
        return tabs.filter { $0.groupId == groupId }
    }

    /// Rearranges tabs array so all tabs belonging to groupId appear together contiguously
    private func clusterGroupTabs(groupId: UUID) {
        let grouped = tabs.filter { $0.groupId == groupId }
        guard !grouped.isEmpty else { return }
        guard let firstIndex = tabs.firstIndex(where: { $0.groupId == groupId }) else { return }

        // Remove all occurrences
        tabs.removeAll(where: { $0.groupId == groupId })
        // Insert them all contiguously starting at firstIndex
        let insertIndex = min(firstIndex, tabs.count)
        tabs.insert(contentsOf: grouped, at: insertIndex)
    }

    // MARK: - BrowserTabDelegate

    public func browserTabDidUpdate(_ tab: BrowserTab) {
        delegate?.tabManager(self, didUpdateTab: tab)
    }

    public func browserTab(_ tab: BrowserTab, requestOpenNewTabWith request: URLRequest) {
        createTab(url: request.url, inGroup: tab.groupId, select: true, insertAfterActive: true)
    }
}
