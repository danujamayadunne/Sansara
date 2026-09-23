import Foundation
import AppKit

@main
struct SansaraTests {
    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual != expected {
            print("FAIL: \(message) - expected \(expected), got \(actual) at \(file):\(line)")
            exit(1)
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if !condition {
            print("FAIL: \(message) - expected true at \(file):\(line)")
            exit(1)
        }
    }

    static func main() {
        print("Running Sansara Unit Tests...")

        // MARK: - Test URLHelper
        print("Testing URLHelper...")

        // 1. Direct URLs with schemes
        let url1 = URLHelper.resolve(input: "https://apple.com")
        assertEqual(url1.absoluteString, "https://apple.com", "Direct https scheme should be preserved")

        let url2 = URLHelper.resolve(input: "http://example.org/test")
        assertEqual(url2.absoluteString, "http://example.org/test", "Direct http scheme should be preserved")

        // 2. Domain names without schemes
        let url3 = URLHelper.resolve(input: "apple.com")
        assertEqual(url3.absoluteString, "https://apple.com", "Domain without scheme should resolve to https")

        let url4 = URLHelper.resolve(input: "news.ycombinator.com/item?id=1")
        assertEqual(url4.absoluteString, "https://news.ycombinator.com/item?id=1", "Subdomain with path should resolve to https")

        // 3. Localhost
        let url5 = URLHelper.resolve(input: "localhost:3000")
        assertEqual(url5.absoluteString, "http://localhost:3000", "Localhost with port should resolve to http")

        // 4. Search queries
        let query1 = URLHelper.resolve(input: "apple macbook")
        assertTrue(query1.absoluteString.hasPrefix("https://www.google.com/search?q="), "Search query should route to Google")
        assertTrue(query1.absoluteString.contains("apple") && query1.absoluteString.contains("macbook"), "Query parameters should be present")

        let query2 = URLHelper.resolve(input: "best mac browser")
        assertTrue(query2.absoluteString.hasPrefix("https://www.google.com/search?q="), "Multi-word text should route to Google search")

        print("✓ URLHelper tests passed")

        // MARK: - Test TabManager
        print("Testing TabManager...")

        let manager = TabManager()
        assertEqual(manager.tabs.count, 0, "Initial tab count should be 0")

        // 1. Create first tab
        let tab1 = manager.createTab(url: nil, select: true)
        assertEqual(manager.tabs.count, 1, "Tab count should be 1")
        assertEqual(manager.activeTabId, tab1.id, "Tab 1 should be active")
        assertTrue(tab1.isNewTabPage, "Tab 1 should be a new tab page")

        // 2. Create second tab with URL
        let testURL = URL(string: "https://apple.com")!
        let tab2 = manager.createTab(url: testURL, select: true)
        assertEqual(manager.tabs.count, 2, "Tab count should be 2")
        assertEqual(manager.activeTabId, tab2.id, "Tab 2 should be active")
        assertEqual(tab2.url?.host, testURL.host, "Tab 2 host should match testURL host")

        // 3. Select tab by index
        manager.selectTab(at: 0)
        assertEqual(manager.activeTabId, tab1.id, "Tab 1 should now be active")

        // 4. Duplicate tab
        manager.duplicateTab(id: tab2.id)
        assertEqual(manager.tabs.count, 3, "Tab count should be 3 after duplication")
        assertEqual(manager.activeTab?.url?.host, testURL.host, "Duplicated tab should have same URL host")

        // 5. Close tab and check history
        let tabToCloseId = manager.activeTabId!
        manager.closeTab(id: tabToCloseId)
        assertEqual(manager.tabs.count, 2, "Tab count should be 2 after closing")
        assertEqual(manager.closedHistory.count, 1, "Closed history should record closed tab")
        assertEqual(manager.closedHistory.last?.url?.host, testURL.host, "History should record URL host")

        // 6. Reopen closed tab
        manager.reopenClosedTab()
        assertEqual(manager.tabs.count, 3, "Tab count should be 3 after reopen")
        assertEqual(manager.closedHistory.count, 0, "Closed history should be empty after reopen")

        // 7. Close other tabs
        let keptTabId = manager.activeTabId!
        manager.closeOtherTabs(except: keptTabId)
        assertEqual(manager.tabs.count, 1, "Only 1 tab should remain")
        assertEqual(manager.activeTabId, keptTabId, "Kept tab should remain active")

        print("✓ TabManager tests passed")

        // MARK: - Test FaviconService
        print("Testing FaviconService...")
        let defaultIcon = FaviconService.defaultIcon
        assertTrue(defaultIcon.size.width > 0, "Default favicon symbol should have valid size")
        print("✓ FaviconService tests passed")

        print("All Sansara Unit Tests Passed Successfully! 🎉")
    }
}
