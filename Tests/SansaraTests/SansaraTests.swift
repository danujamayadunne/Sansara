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

        // 8. Test Tab Groups
        let group1 = manager.createGroup(name: "Research", color: .purple)
        assertEqual(manager.groups.count, 1, "Should have 1 group")
        assertEqual(group1.name, "Research", "Group name should be Research")
        assertEqual(group1.color, .purple, "Group color should be Purple")
        assertEqual(group1.isCollapsed, false, "Group should initially be expanded")

        // Add active tab to group
        manager.addTabs([keptTabId], to: group1.id)
        assertEqual(manager.tabs[0].groupId, group1.id, "Tab should belong to group1")

        // Create new tab directly in group
        let groupedTab2 = manager.createTab(url: URL(string: "https://example.com"), inGroup: group1.id, select: false)
        assertEqual(groupedTab2.groupId, group1.id, "New tab should be in group1")
        assertEqual(manager.tabs(for: group1.id).count, 2, "Group 1 should have 2 tabs")

        // Rename group & change color
        manager.renameGroup(id: group1.id, newName: "Studies")
        assertEqual(group1.name, "Studies", "Group should be renamed")
        manager.setGroupColor(id: group1.id, color: .orange)
        assertEqual(group1.color, .orange, "Group color should be Orange")

        // Toggle collapse
        manager.toggleGroupCollapsed(id: group1.id)
        assertEqual(group1.isCollapsed, true, "Group should be collapsed")
        manager.toggleGroupCollapsed(id: group1.id)
        assertEqual(group1.isCollapsed, false, "Group should be expanded")

        // Duplicate grouped tab
        manager.duplicateTab(id: groupedTab2.id)
        assertEqual(manager.tabs(for: group1.id).count, 3, "Group should have 3 tabs after duplication")

        // Remove a tab from group
        manager.removeTabFromGroup(id: groupedTab2.id)
        assertEqual(groupedTab2.groupId, nil, "Tab should be ungrouped")
        assertEqual(manager.tabs(for: group1.id).count, 2, "Group should now have 2 tabs")

        // Reordering & Moving tabs (drag & drop simulation)
        let tabA = manager.tabs[0]
        let tabB = manager.tabs[1]
        manager.moveTab(id: tabB.id, beforeOrAfter: tabA.id, placeAfter: false)
        assertEqual(manager.tabs[0].id, tabB.id, "Tab B should be first after moving before Tab A")
        manager.moveTabToEnd(id: tabB.id)
        assertEqual(manager.tabs.last?.id, tabB.id, "Tab B should be at end after moveTabToEnd")

        // Test auto-create folder with default blue
        let newTabX = manager.createTab(url: URL(string: "https://a.com"), select: false)
        let newTabY = manager.createTab(url: URL(string: "https://b.com"), select: false)
        let autoFolder = manager.createGroup(name: "New Folder", color: .blue, tabIds: [newTabX.id, newTabY.id])
        assertEqual(autoFolder.name, "New Folder", "Default folder name should be New Folder")
        assertEqual(autoFolder.color, .blue, "Default folder color should be Blue")
        assertEqual(newTabX.groupId, autoFolder.id, "Tab X should be in auto folder")
        assertEqual(newTabY.groupId, autoFolder.id, "Tab Y should be in auto folder")

        // MARK: - Tab Strip Drag & Drop Operations
        print("Testing Tab Strip Drag & Drop Reordering...")
        let stripTab1 = manager.createTab(url: URL(string: "https://site1.com"), select: false)
        let stripTab2 = manager.createTab(url: URL(string: "https://site2.com"), select: false)
        let stripTab3 = manager.createTab(url: URL(string: "https://site3.com"), select: false)

        // Test drop after: Move stripTab1 after stripTab2
        manager.moveTab(id: stripTab1.id, beforeOrAfter: stripTab2.id, placeAfter: true)
        let idx1After2 = manager.tabs.firstIndex(where: { $0.id == stripTab1.id })!
        let idx2 = manager.tabs.firstIndex(where: { $0.id == stripTab2.id })!
        assertTrue(idx1After2 > idx2, "stripTab1 should be placed after stripTab2")

        // Test drop before: Move stripTab3 before stripTab2
        manager.moveTab(id: stripTab3.id, beforeOrAfter: stripTab2.id, placeAfter: false)
        let idx3 = manager.tabs.firstIndex(where: { $0.id == stripTab3.id })!
        let idx2After3 = manager.tabs.firstIndex(where: { $0.id == stripTab2.id })!
        assertTrue(idx3 < idx2After3, "stripTab3 should be placed before stripTab2")

        // Test drag tab into group
        let stripGroup = manager.createGroup(name: "Work", color: .green, tabIds: [])
        manager.addTabs([stripTab3.id], to: stripGroup.id)
        assertEqual(stripTab3.groupId, stripGroup.id, "stripTab3 should now belong to stripGroup")
        assertEqual(manager.tabs(for: stripGroup.id).count, 1, "stripGroup should have 1 tab")

        // Test drag tab out of group and place after stripTab1
        manager.removeTabFromGroup(id: stripTab3.id)
        manager.moveTab(id: stripTab3.id, beforeOrAfter: stripTab1.id, placeAfter: true)
        assertEqual(stripTab3.groupId, nil, "stripTab3 should now be ungrouped")
        let finalIdx3 = manager.tabs.firstIndex(where: { $0.id == stripTab3.id })!
        let finalIdx1 = manager.tabs.firstIndex(where: { $0.id == stripTab1.id })!
        assertTrue(finalIdx3 > finalIdx1, "stripTab3 should be placed after stripTab1")

        // Test drag to end
        manager.moveTabToEnd(id: stripTab2.id)
        assertEqual(manager.tabs.last?.id, stripTab2.id, "stripTab2 should be at the very end after moveTabToEnd")

        print("✓ TabManager tests passed")

        // MARK: - Test FaviconService
        print("Testing FaviconService Privacy & Security...")
        let defaultIcon = FaviconService.defaultIcon
        assertTrue(defaultIcon.size.width > 0, "Default favicon symbol should have valid size")

        let monogram = FaviconService.shared.monogramIcon(for: "apple.com")
        assertTrue(monogram.size.width == 16 && monogram.size.height == 16, "Monogram icon should be 16x16")

        FaviconService.shared.cacheFavicon(monogram, for: "apple.com")

        // Test SSRF / loopback / private IP filtering
        assertTrue(!FaviconService.isSafeHost("localhost"), "localhost should be blocked from favicon fetching")
        assertTrue(!FaviconService.isSafeHost("127.0.0.1"), "127.0.0.1 should be blocked")
        assertTrue(!FaviconService.isSafeHost("::1"), "::1 loopback should be blocked")
        assertTrue(!FaviconService.isSafeHost("0.0.0.0"), "0.0.0.0 should be blocked")
        assertTrue(!FaviconService.isSafeHost("169.254.169.254"), "AWS/cloud metadata should be blocked")
        assertTrue(!FaviconService.isSafeHost("10.0.1.5"), "RFC 1918 10.x.x.x should be blocked")
        assertTrue(!FaviconService.isSafeHost("192.168.1.1"), "RFC 1918 192.168.x.x should be blocked")
        assertTrue(!FaviconService.isSafeHost("172.16.0.1"), "RFC 1918 172.16.x.x should be blocked")
        assertTrue(!FaviconService.isSafeHost("172.31.255.255"), "RFC 1918 172.31.x.x should be blocked")
        assertTrue(!FaviconService.isSafeHost("fe80::1"), "IPv6 link-local should be blocked")
        assertTrue(!FaviconService.isSafeHost("fc00::1"), "IPv6 unique local should be blocked")

        // Test Tracker Host blocking
        assertTrue(!FaviconService.isSafeHost("google-analytics.com"), "Google Analytics should be blocked from favicon fetching")
        assertTrue(!FaviconService.isSafeHost("googletagmanager.com"), "Google Tag Manager should be blocked")
        assertTrue(!FaviconService.isSafeHost("doubleclick.net"), "DoubleClick should be blocked")
        assertTrue(!FaviconService.isSafeHost("pixel.facebook.com"), "Facebook Pixel should be blocked")
        assertTrue(!FaviconService.isSafeHost("ads-twitter.com"), "Twitter Ads should be blocked")

        // Safe hosts should be allowed
        assertTrue(FaviconService.isSafeHost("apple.com"), "Public host apple.com should be safe")
        assertTrue(FaviconService.isSafeHost("github.com"), "Public host github.com should be safe")
        assertTrue(FaviconService.isSafeHost("wikipedia.org"), "Public host wikipedia.org should be safe")

        // Test data URI in-memory resolution (zero-network, zero-leak)
        let samplePNGDataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        var decodedImage: NSImage?
        let exp = DispatchSemaphore(value: 0)
        FaviconService.shared.resolveDOMFavicon(href: samplePNGDataURI, documentURL: URL(string: "https://example.com")) { img in
            decodedImage = img
            exp.signal()
        }
        _ = exp.wait(timeout: .now() + 1.0)
        assertTrue(decodedImage != nil, "Data URI favicon should decode directly in memory")

        // Test clearCache
        FaviconService.shared.clearCache()
        print("✓ FaviconService tests passed")

        // MARK: - Test ContentBlockerService
        print("Testing ContentBlockerService...")
        assertTrue(ContentBlockerService.isTracker(host: "google-analytics.com"), "google-analytics.com should be recognized as tracker")
        assertTrue(ContentBlockerService.isTracker(host: "analytics.google.com"), "subdomain of google tracker should be recognized")
        assertTrue(ContentBlockerService.isTracker(host: "googletagmanager.com"), "googletagmanager.com should be recognized as tracker")
        assertTrue(ContentBlockerService.isTracker(host: "doubleclick.net"), "doubleclick.net should be recognized as tracker")
        assertTrue(ContentBlockerService.isTracker(host: "connect.facebook.net"), "connect.facebook.net should be recognized as tracker")
        assertTrue(!ContentBlockerService.isTracker(host: "apple.com"), "apple.com is not a tracker")
        assertTrue(!ContentBlockerService.isTracker(host: "github.com"), "github.com is not a tracker")
        assertTrue(!ContentBlockerService.isTracker(host: "duckduckgo.com"), "duckduckgo.com is not a tracker")
        print("✓ ContentBlockerService tests passed")

        // MARK: - Test BrowserTab Tab Nap & Memory Suspension
        print("Testing BrowserTab Tab Nap (Suspension & Wake)...")
        let suspendedTab = manager.createTab(url: URL(string: "https://apple.com"), select: false)
        _ = suspendedTab.webView // instantiate web view
        assertTrue(suspendedTab.hasInstantiatedWebView, "Tab should have instantiated web view")
        assertEqual(suspendedTab.isSuspended, false, "Tab should initially not be suspended")

        suspendedTab.suspend()
        assertEqual(suspendedTab.isSuspended, true, "Tab should be marked suspended after suspend()")
        assertEqual(suspendedTab.hasInstantiatedWebView, false, "Tab web view should be nil after suspend()")
        assertEqual(suspendedTab.url?.host, "apple.com", "Tab URL should be preserved during suspension")

        suspendedTab.wakeIfNeeded()
        assertEqual(suspendedTab.isSuspended, false, "Tab should not be suspended after wakeIfNeeded()")
        assertTrue(suspendedTab.hasInstantiatedWebView, "Tab web view should be re-instantiated after wake")

        // Test TabManager suspendInactiveTabs
        manager.suspendInactiveTabs(maxActiveTabs: 1)
        assertEqual(suspendedTab.isSuspended, true, "Tab should be suspended by TabManager when inactive")
        print("✓ BrowserTab Tab Nap tests passed")

        // MARK: - Test Tab Renaming
        print("Testing BrowserTab Custom Title & Renaming...")
        let renameTab = manager.createTab(url: URL(string: "https://apple.com"), select: true)
        assertEqual(renameTab.title, "apple.com", "Initial title should match URL host")
        assertEqual(renameTab.customTitle, nil, "Initial customTitle should be nil")

        // Rename with custom title
        renameTab.rename(to: "Apple Official")
        assertEqual(renameTab.title, "Apple Official", "Tab title should reflect custom title")
        assertEqual(renameTab.customTitle, "Apple Official", "customTitle should be set")

        // Rename with blank string should reset to webTitle
        renameTab.rename(to: "   ")
        assertEqual(renameTab.customTitle, nil, "Blank rename should clear customTitle")
        assertEqual(renameTab.title, "apple.com", "Reset title should revert back to webTitle")
        print("✓ BrowserTab Renaming tests passed")

        // MARK: - Test Inline Tab Renaming
        print("Testing Inline Tab Renaming Components...")
        let tabItemView = TabItemView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        tabItemView.configure(with: renameTab, isSelected: true)
        assertEqual(tabItemView.isEditing, false, "TabItemView should not be editing initially")

        // Start inline editing
        tabItemView.startEditing()
        assertEqual(tabItemView.isEditing, true, "TabItemView should be in editing mode after startEditing()")

        // Finish inline editing
        tabItemView.finishEditing(newTitle: "Custom Apple Title")
        assertEqual(tabItemView.isEditing, false, "TabItemView should exit editing mode after finishEditing()")
        assertEqual(renameTab.title, "Custom Apple Title", "Tab title should update to new name")

        // Start editing and cancel
        tabItemView.startEditing()
        assertEqual(tabItemView.isEditing, true, "TabItemView should be editing again")
        tabItemView.cancelEditing()
        assertEqual(tabItemView.isEditing, false, "TabItemView should exit editing mode after cancelEditing()")
        assertEqual(renameTab.title, "Custom Apple Title", "Tab title should be unchanged after cancel")

        // Test InlineRenameTextField commit and cancel
        let inlineField = InlineRenameTextField()
        var committedText: String?
        var didCancel = false
        inlineField.onCommit = { committedText = $0 }
        inlineField.onCancel = { didCancel = true }

        inlineField.stringValue = "New Work Tab"
        inlineField.commit()
        assertEqual(committedText, "New Work Tab", "InlineRenameTextField should commit stringValue")

        let cancelField = InlineRenameTextField()
        cancelField.onCancel = { didCancel = true }
        cancelField.cancel()
        assertEqual(didCancel, true, "InlineRenameTextField should trigger cancel")

        // Test runloop persistence in window hierarchy (verifying it does not quickly hide)
        let testWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        testWindow.contentView?.addSubview(tabItemView)
        testWindow.makeKeyAndOrderFront(nil)

        tabItemView.startEditing()
        assertEqual(tabItemView.isEditing, true, "TabItemView should be editing immediately")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        assertEqual(tabItemView.isEditing, true, "TabItemView should REMAIN editing after runloop cycle without disappearing")

        tabItemView.finishEditing(newTitle: "Persistent Title")
        assertEqual(tabItemView.isEditing, false, "TabItemView should stop editing after finishEditing")
        assertEqual(renameTab.title, "Persistent Title", "Tab title should update to Persistent Title")

        print("✓ Inline Tab Renaming tests passed")

        // MARK: - Test Sidebar Colors (Light: White, Dark: Matte Black)
        print("Testing Sidebar Colors & Appearance...")
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!

        let lightColor = SidebarColors.color(for: lightAppearance)
        assertEqual(lightColor, SidebarColors.lightBackground, "Sidebar in light mode should be white")
        assertEqual(lightColor, NSColor.white, "Sidebar light background should match NSColor.white")

        let darkColor = SidebarColors.color(for: darkAppearance)
        assertEqual(darkColor, SidebarColors.matteBlackBackground, "Sidebar in dark mode should be matte black")
        assertEqual(
            darkColor,
            NSColor(srgbRed: 20.0 / 255.0, green: 20.0 / 255.0, blue: 20.0 / 255.0, alpha: 1.0),
            "Sidebar dark background should match matte black #141414"
        )

        let sidebarView = SidebarBackgroundView(frame: NSRect(x: 0, y: 0, width: 250, height: 600))
        assertTrue(sidebarView.wantsUpdateLayer, "SidebarBackgroundView should want update layer")
        assertTrue(sidebarView.isOpaque, "SidebarBackgroundView should be opaque")
        print("✓ Sidebar Colors & Appearance tests passed")

        // MARK: - Test Tab Stripe Colors (Light: ControlBackgroundColor/White card, Dark: Elevated Luminous)
        print("Testing Tab Stripe Colors & Appearance...")
        let stripeLightBg = TabStripeColors.activeBackgroundColor(for: lightAppearance)
        assertEqual(stripeLightBg, TabStripeColors.lightActiveBackground, "Tab stripe active tab in light mode should be controlBackgroundColor")
        assertEqual(stripeLightBg, NSColor.controlBackgroundColor, "Light active background should match controlBackgroundColor")

        let stripeDarkBg = TabStripeColors.activeBackgroundColor(for: darkAppearance)
        assertEqual(stripeDarkBg, TabStripeColors.darkActiveBackground, "Tab stripe active tab in dark mode should be luminous dark")

        let stripeLightBorder = TabStripeColors.activeBorderColor(for: lightAppearance)
        assertEqual(stripeLightBorder, TabStripeColors.lightActiveBorder, "Tab stripe border in light mode should be subtle black tint")

        let stripeDarkBorder = TabStripeColors.activeBorderColor(for: darkAppearance)
        assertEqual(stripeDarkBorder, TabStripeColors.darkActiveBorder, "Tab stripe border in dark mode should be subtle white tint")

        let stripeLightInactive = TabStripeColors.inactiveBackgroundColor(for: lightAppearance)
        assertEqual(stripeLightInactive, TabStripeColors.lightInactiveBackground, "Tab stripe inactive tab in light mode should be subtle light gray")

        let stripeDarkInactive = TabStripeColors.inactiveBackgroundColor(for: darkAppearance)
        assertEqual(stripeDarkInactive, TabStripeColors.darkInactiveBackground, "Tab stripe inactive tab in dark mode should be subtle elevated dark gray")

        let stripeLightHover = TabStripeColors.hoverBackgroundColor(for: lightAppearance)
        assertEqual(stripeLightHover, TabStripeColors.lightHoverBackground, "Tab stripe hover tab in light mode should be hover gray")

        let stripeDarkHover = TabStripeColors.hoverBackgroundColor(for: darkAppearance)
        assertEqual(stripeDarkHover, TabStripeColors.darkHoverBackground, "Tab stripe hover tab in dark mode should be hover dark gray")
        print("✓ Tab Stripe Colors & Appearance tests passed")

        // MARK: - Test Content Colors (Light: White, Dark: Matte Black)
        print("Testing Content Colors & Appearance...")
        let contentLightBg = ContentColors.color(for: lightAppearance)
        assertEqual(contentLightBg, ContentColors.lightBackground, "Content in light mode should be white")
        assertEqual(contentLightBg, NSColor.white, "Content light background should match NSColor.white")

        let contentDarkBg = ContentColors.color(for: darkAppearance)
        assertEqual(contentDarkBg, ContentColors.matteBlackBackground, "Content in dark mode should be matte black")
        assertEqual(
            contentDarkBg,
            NSColor(srgbRed: 20.0 / 255.0, green: 20.0 / 255.0, blue: 20.0 / 255.0, alpha: 1.0),
            "Content dark background should match matte black #141414"
        )
        print("✓ Content Colors & Appearance tests passed")

        // MARK: - Test FolderItemView & Plus Button Click Handling
        print("Testing FolderItemView & Plus Button Click Handling...")
        let folderView = FolderItemView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        let testGroup = manager.createGroup(name: "Projects", color: .purple)
        testGroup.isCollapsed = true
        folderView.configure(with: testGroup, tabCount: 0)

        var toggledCollapse = false
        var addedTab = false
        folderView.onToggleCollapse = { toggledCollapse = true }
        folderView.onAddTab = { addedTab = true }

        // Host in a window for coordinate conversion
        let folderTestWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        folderTestWindow.contentView?.addSubview(folderView)
        folderView.layoutSubtreeIfNeeded()

        // Simulate hover
        let enterEvent = NSEvent.enterExitEvent(
            with: .mouseEntered,
            location: NSPoint(x: 50, y: 15),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: folderTestWindow.windowNumber,
            context: nil,
            eventNumber: 1,
            trackingNumber: 1,
            userData: nil
        )!
        folderView.mouseEntered(with: enterEvent)

        // Point near trailing edge where addTabButton resides
        let addBtnPoint = NSPoint(x: folderView.frame.width - 12, y: 15)
        let addBtnWindowPoint = folderView.convert(addBtnPoint, to: nil)

        assertTrue(folderView.isPointInAddButton(addBtnWindowPoint), "Point in plus button should be detected by isPointInAddButton")

        // Clicking on plus button should NOT toggle collapse
        let plusClickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: addBtnWindowPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: folderTestWindow.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1.0
        )!
        folderView.mouseDown(with: plusClickEvent)
        assertEqual(toggledCollapse, false, "Clicking plus button should NOT toggle folder collapse")

        // hitTest at add button point should return addTabButton
        _ = folderView.hitTest(folderView.frame.origin) // test outside
        let hitAddBtn = folderView.hitTest(NSPoint(x: folderView.frame.width - 12, y: 15))
        assertTrue(hitAddBtn is NSButton, "hitTest at plus button location should return the NSButton")
        (hitAddBtn as? NSButton)?.performClick(nil)
        assertEqual(addedTab, true, "Performing click on hit-tested button should trigger onAddTab")

        // Clicking on folder row outside plus button SHOULD toggle collapse
        let folderRowPoint = NSPoint(x: 50, y: 15)
        let folderRowWindowPoint = folderView.convert(folderRowPoint, to: nil)
        let rowClickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: folderRowWindowPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: folderTestWindow.windowNumber,
            context: nil,
            eventNumber: 3,
            clickCount: 1,
            pressure: 1.0
        )!
        folderView.mouseDown(with: rowClickEvent)
        assertEqual(toggledCollapse, true, "Clicking folder row outside plus button should toggle collapse")

        // Test creating tab in collapsed folder auto-expands it
        assertEqual(testGroup.isCollapsed, true, "testGroup should be collapsed initially")
        let tabInCollapsed = manager.createTab(url: nil, inGroup: testGroup.id, select: true)
        assertEqual(testGroup.isCollapsed, false, "Creating tab in collapsed folder should auto-expand it")
        assertEqual(tabInCollapsed.groupId, testGroup.id, "Created tab should belong to the folder")
        print("✓ FolderItemView & Plus Button tests passed")

        // MARK: - Test SettingsManager
        print("Testing SettingsManager...")
        let suite = "com.sansara.tests.settings.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suite)!
        testDefaults.removePersistentDomain(forName: suite)
        let settings = SettingsManager(defaults: testDefaults)
        assertEqual(settings.searchEngine, .google, "Default search engine should be Google")
        assertEqual(settings.appearanceMode, .system, "Default appearance should be System")
        assertEqual(settings.newTabPageMode, .image, "Default new tab mode should be Image")
        assertEqual(settings.isContentBlockerEnabled, true, "Default content blocker should be enabled")
        assertEqual(settings.tabNapEnabled, true, "Default tab nap should be enabled")
        assertEqual(settings.tabNapThreshold, 15, "Default tab nap threshold should be 15")

        // Change search engine
        settings.searchEngine = .duckDuckGo
        assertEqual(settings.searchEngine, .duckDuckGo, "Search engine should update to DuckDuckGo")
        assertEqual(settings.searchEngine.searchEndpoint, "https://duckduckgo.com/?q=", "DuckDuckGo search endpoint should match")

        let ddgQueryURL = settings.searchEngine.searchURL(for: "privacy browser")
        assertTrue(ddgQueryURL.absoluteString.contains("duckduckgo.com/?q=privacy%20browser"), "Search URL should be formatted properly")

        // Change appearance
        settings.appearanceMode = .dark
        assertEqual(settings.appearanceMode, .dark, "Appearance mode should update to Dark")

        // Change New Tab Page Mode
        settings.newTabPageMode = .blank
        assertEqual(settings.newTabPageMode, .blank, "New tab page mode should update to Blank")
        settings.newTabPageMode = .image
        assertEqual(settings.newTabPageMode, .image, "New tab page mode should update to Image")

        // Test Custom Wallpaper Path
        assertEqual(settings.customWallpaperPath, nil, "Default custom wallpaper should be nil")
        settings.customWallpaperPath = "/tmp/test_wallpaper.jpg"
        assertEqual(settings.customWallpaperPath, "/tmp/test_wallpaper.jpg", "Custom wallpaper path should update")
        settings.resetToDefaults()
        assertEqual(settings.customWallpaperPath, nil, "Reset should clear custom wallpaper path")

        // Test SearchEngine homeURL and empty input resolution
        assertEqual(SearchEngine.google.homeURL.absoluteString, "https://www.google.com", "Google homeURL should match")
        assertEqual(SearchEngine.duckDuckGo.homeURL.absoluteString, "https://duckduckgo.com", "DuckDuckGo homeURL should match")
        assertEqual(SearchEngine.brave.homeURL.absoluteString, "https://search.brave.com", "Brave homeURL should match")

        SettingsManager.shared.searchEngine = .duckDuckGo
        let emptyResolvedDDG = URLHelper.resolve(input: "   ")
        assertEqual(emptyResolvedDDG.absoluteString, "https://duckduckgo.com", "Empty query should resolve to configured searchEngine homeURL")

        SettingsManager.shared.resetToDefaults()
        let emptyResolvedDefault = URLHelper.resolve(input: "")
        assertEqual(emptyResolvedDefault.absoluteString, "https://www.google.com", "Empty query with default settings should resolve to Google")

        print("✓ SettingsManager tests passed")

        // MARK: - Test HistoryManager
        print("Testing HistoryManager...")
        let tempHistoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sansara_test_history_\(UUID().uuidString).json")
        let historyMgr = HistoryManager(fileURL: tempHistoryURL)
        historyMgr.clearAll()
        assertEqual(historyMgr.allHistory().count, 0, "Initial test history count should be 0")

        // Add visits
        let appleURL = URL(string: "https://www.apple.com")!
        let visit1 = historyMgr.addVisit(url: appleURL, title: "Apple")
        assertTrue(visit1 != nil, "Visit should be added")
        assertEqual(historyMgr.allHistory().count, 1, "History count should be 1")
        assertEqual(historyMgr.allHistory().first?.url, appleURL, "History URL should match")
        assertEqual(historyMgr.allHistory().first?.title, "Apple", "History title should match")

        // Duplicate debounce
        _ = historyMgr.addVisit(url: appleURL, title: "Apple Inc")
        assertEqual(historyMgr.allHistory().count, 1, "Duplicate visit within 5s should be debounced")
        assertEqual(historyMgr.allHistory().first?.title, "Apple Inc", "Debounced visit should update title")

        // Add second visit
        let ghURL = URL(string: "https://github.com/swiftlang/swift")!
        historyMgr.addVisit(url: ghURL, title: "Swift Repo")
        assertEqual(historyMgr.allHistory().count, 2, "History count should be 2")
        assertEqual(historyMgr.recentHistory(limit: 1).first?.url, ghURL, "Most recent visit should be GitHub")

        // Title update
        historyMgr.updateTitle(for: ghURL, title: "GitHub - Swift Language")
        assertEqual(historyMgr.allHistory().first?.title, "GitHub - Swift Language", "History title should update")

        // Search
        let searchResults = historyMgr.search(query: "swiftlang")
        assertEqual(searchResults.count, 1, "Search should find matching entry")
        assertEqual(searchResults.first?.title, "GitHub - Swift Language", "Search result should match title")

        // Delete single entry
        let itemToDelete = searchResults.first!
        historyMgr.deleteItem(id: itemToDelete.id)
        assertEqual(historyMgr.allHistory().count, 1, "History count should decrease to 1")

        // Clear all
        historyMgr.clearAll()
        assertEqual(historyMgr.allHistory().count, 0, "History count should be 0 after clearAll")
        try? FileManager.default.removeItem(at: tempHistoryURL)

        print("✓ HistoryManager tests passed")

        // MARK: - Test BookmarkManager
        print("Testing BookmarkManager...")
        let tempBookmarksURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sansara_test_bookmarks_\(UUID().uuidString).json")
        let bmarkMgr = BookmarkManager(fileURL: tempBookmarksURL)
        bmarkMgr.clearAll()
        assertEqual(bmarkMgr.allBookmarks().count, 0, "Initial test bookmarks count should be 0")

        // Add bookmark
        _ = bmarkMgr.addBookmark(title: "DuckDuckGo", url: URL(string: "https://duckduckgo.com")!, folder: "Search")
        assertEqual(bmarkMgr.allBookmarks().count, 1, "Bookmark count should be 1")
        assertTrue(bmarkMgr.isBookmarked(url: URL(string: "https://duckduckgo.com")), "isBookmarked should return true")
        assertTrue(bmarkMgr.isBookmarked(url: URL(string: "https://duckduckgo.com/")), "isBookmarked should normalize trailing slash")

        // Toggle bookmark
        let toggledOff = bmarkMgr.toggleBookmark(title: "DuckDuckGo", url: URL(string: "https://duckduckgo.com")!)
        assertEqual(toggledOff, false, "toggleBookmark on existing should remove it and return false")
        assertEqual(bmarkMgr.allBookmarks().count, 0, "Bookmark count should be 0 after toggle off")

        let toggledOn = bmarkMgr.toggleBookmark(title: "DuckDuckGo", url: URL(string: "https://duckduckgo.com")!)
        assertEqual(toggledOn, true, "toggleBookmark on missing should add it and return true")
        assertEqual(bmarkMgr.allBookmarks().count, 1, "Bookmark count should be 1 after toggle on")

        // Update bookmark
        let currentBmark = bmarkMgr.allBookmarks().first!
        bmarkMgr.updateBookmark(id: currentBmark.id, title: "DDG Privacy Search", url: currentBmark.url, folder: "Privacy")
        assertEqual(bmarkMgr.allBookmarks().first?.title, "DDG Privacy Search", "Bookmark title should update")
        assertEqual(bmarkMgr.allBookmarks().first?.folder, "Privacy", "Bookmark folder should update")

        // Search bookmarks
        let bmarkResults = bmarkMgr.search(query: "privacy")
        assertEqual(bmarkResults.count, 1, "Search should return 1 matching bookmark")

        // Remove bookmark
        bmarkMgr.removeBookmark(id: currentBmark.id)
        assertEqual(bmarkMgr.allBookmarks().count, 0, "Bookmark count should be 0 after removeBookmark")
        try? FileManager.default.removeItem(at: tempBookmarksURL)

        print("✓ BookmarkManager tests passed")

        // MARK: - Test SearchSuggestionsProvider & Verified Domains
        print("Testing SearchSuggestionsProvider...")
        let searchHistoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sansara_test_history_search_\(UUID().uuidString).json")
        let searchHistoryMgr = HistoryManager(fileURL: searchHistoryURL)
        searchHistoryMgr.clearAll()

        let provider = SearchSuggestionsProvider(historyManager: searchHistoryMgr)

        // 1. When history is empty ("if not search"): empty query should return top verified domains!
        let emptyHistorySuggestions = provider.suggestions(for: "")
        assertEqual(emptyHistorySuggestions.count, 5, "When no search history exists, should return 5 verified domains")
        assertTrue(emptyHistorySuggestions.allSatisfy { $0.kind == .verifiedDomain }, "All items should be verified domains")
        let verifiedDomainsInEmpty = emptyHistorySuggestions.map { $0.displayURL }
        assertTrue(verifiedDomainsInEmpty.contains("x.com"), "Verified domains should contain x.com")
        assertTrue(verifiedDomainsInEmpty.contains("youtube.com"), "Verified domains should contain youtube.com")

        // 2. Query not in history ("if not search"): should return according verified domains
        let twitchResults = provider.suggestions(for: "twitch")
        assertEqual(twitchResults.count, 1, "Twitch query should return according verified domain")
        assertEqual(twitchResults[0].displayURL, "twitch.tv", "Verified domain should be twitch.tv")
        assertEqual(twitchResults[0].kind, .verifiedDomain, "Kind should be verifiedDomain")

        let xResults = provider.suggestions(for: "x")
        assertTrue(xResults.contains(where: { $0.displayURL == "x.com" && $0.kind == .verifiedDomain }), "x query should match x.com verified domain")

        let redditResults = provider.suggestions(for: "red")
        assertTrue(redditResults.contains(where: { $0.displayURL == "reddit.com" }), "red query should match reddit.com")

        let instaResults = provider.suggestions(for: "insta")
        assertTrue(instaResults.contains(where: { $0.displayURL == "instagram.com" }), "insta query should match instagram.com")

        let fbResults = provider.suggestions(for: "face")
        assertTrue(fbResults.contains(where: { $0.displayURL == "facebook.com" }), "face query should match facebook.com")

        // 3. Populate history visits
        searchHistoryMgr.addVisit(url: URL(string: "https://www.apple.com/")!, title: "Apple")
        searchHistoryMgr.addVisit(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News")
        searchHistoryMgr.addVisit(url: URL(string: "https://github.com/apple/swift")!, title: "apple/swift: The Swift Programming Language")
        searchHistoryMgr.addVisit(url: URL(string: "https://github.com/")!, title: "GitHub: Let's build from here")
        searchHistoryMgr.addVisit(url: URL(string: "https://duckduckgo.com/?q=apple")!, title: "apple at DuckDuckGo")
        searchHistoryMgr.addVisit(url: URL(string: "https://github.com/")!, title: "GitHub - Earlier Visit") // duplicate URL

        // 4. When history is populated, empty query should return top 5 recent history searches
        let populatedRecent = provider.suggestions(for: "")
        assertEqual(populatedRecent.count, 5, "Should return top 5 recent searches")
        assertTrue(populatedRecent.allSatisfy { $0.kind == .history }, "Recent visits should be history kind")

        // 5. Deduplication and matching: "git" should return GitHub verified domain / history items
        let gitSuggestions = provider.suggestions(for: "git")
        assertTrue(gitSuggestions.count <= 5, "Results count should be <= 5")
        assertTrue(gitSuggestions.contains(where: { $0.displayURL.contains("github.com") }), "Results should contain github.com")

        // 6. Host prefix ranking: typing "apple" should rank apple.com
        let appleSuggestions = provider.suggestions(for: "apple")
        assertTrue(appleSuggestions.count <= 5, "Results count should be <= 5")
        assertTrue(appleSuggestions[0].displayURL.contains("apple.com"), "Top result should be apple.com")

        // 7. Multi-token query: "apple swift"
        let multiTokenSuggestions = provider.suggestions(for: "apple swift")
        assertEqual(multiTokenSuggestions.count, 1, "Should match item containing both apple and swift")
        assertEqual(multiTokenSuggestions[0].url.path, "/apple/swift", "Matched path should be /apple/swift")

        // 8. maxCount constraint
        let limitedSuggestions = provider.suggestions(for: "apple", maxCount: 2)
        assertEqual(limitedSuggestions.count, 2, "maxCount of 2 should return exactly 2 items")

        // 9. Display string formatting
        assertEqual(SearchSuggestionsProvider.displayString(for: URL(string: "https://apple.com/")!), "apple.com", "https and trailing slash stripped")
        assertEqual(SearchSuggestionsProvider.displayString(for: URL(string: "http://example.org/path")!), "example.org/path", "http stripped")

        try? FileManager.default.removeItem(at: searchHistoryURL)
        print("✓ SearchSuggestionsProvider tests passed")

        // MARK: - Test SearchHistoryDropdownView
        print("Testing SearchHistoryDropdownView...")
        let dropdown = SearchHistoryDropdownView()
        assertTrue(dropdown.isHidden, "Dropdown should be hidden initially")
        assertEqual(dropdown.items.count, 0, "Initial items count should be 0")
        assertEqual(dropdown.selectedItem, nil, "No item selected initially")

        let sampleItems = [
            SearchSuggestion(title: "GitHub", url: URL(string: "https://github.com")!, kind: .verifiedDomain),
            SearchSuggestion(title: "Apple", url: URL(string: "https://apple.com")!, kind: .verifiedDomain),
            SearchSuggestion(title: "Hacker News", url: URL(string: "https://news.ycombinator.com")!, kind: .history)
        ]

        dropdown.update(items: sampleItems)
        assertEqual(dropdown.isHidden, false, "Dropdown should be visible after update with items")
        assertEqual(dropdown.items.count, 3, "Dropdown should have 3 items")
        assertEqual(dropdown.selectedIndex, nil, "Selected index should be nil before navigation")

        // Keyboard arrow down navigation
        dropdown.selectNext()
        assertEqual(dropdown.selectedIndex, 0, "selectNext should select index 0")
        assertEqual(dropdown.selectedItem?.title, "GitHub", "Selected item should be GitHub")

        dropdown.selectNext()
        assertEqual(dropdown.selectedIndex, 1, "selectNext should select index 1")
        assertEqual(dropdown.selectedItem?.title, "Apple", "Selected item should be Apple")

        dropdown.selectNext()
        assertEqual(dropdown.selectedIndex, 2, "selectNext should select index 2")
        assertEqual(dropdown.selectedItem?.title, "Hacker News", "Selected item should be Hacker News")

        // Reaching end should stay at last index
        dropdown.selectNext()
        assertEqual(dropdown.selectedIndex, 2, "selectNext at end should clamp to last index")

        // Keyboard arrow up navigation
        dropdown.selectPrevious()
        assertEqual(dropdown.selectedIndex, 1, "selectPrevious should move back to index 1")

        dropdown.selectPrevious()
        assertEqual(dropdown.selectedIndex, 0, "selectPrevious should move back to index 0")

        dropdown.selectPrevious()
        assertEqual(dropdown.selectedIndex, nil, "selectPrevious from 0 should reset to nil (unselected)")
        assertEqual(dropdown.selectedItem, nil, "selectedItem should be nil")

        // Hide dropdown
        dropdown.hide()
        assertTrue(dropdown.isHidden, "Dropdown should be hidden after hide()")
        assertEqual(dropdown.items.count, 0, "Items should be cleared after hide()")

        // MARK: - Test SettingsWindowController & Sidebar Categorization
        print("Testing SettingsWindowController & Sidebar Categorization...")
        assertEqual(SettingsCategory.allCases.count, 3, "Settings should have 3 categories: General, Appearance, Privacy")
        assertEqual(SettingsCategory.general.rawValue, "General", "General category raw value should match")
        assertEqual(SettingsCategory.appearance.rawValue, "Appearance", "Appearance category raw value should match")
        assertEqual(SettingsCategory.privacy.rawValue, "Privacy", "Privacy category raw value should match")

        let settingsWC = SettingsWindowController()
        assertEqual(settingsWC.currentCategory, .general, "Initial category should be General")
        assertEqual(settingsWC.window?.title, "General", "Window title should initially match General")
        assertTrue((settingsWC.window?.frame.width ?? 0) >= 600, "Window frame width should accommodate sidebar design")

        // Switch to Appearance
        settingsWC.selectCategory(.appearance)
        assertEqual(settingsWC.currentCategory, .appearance, "Active category should switch to Appearance")
        assertEqual(settingsWC.window?.title, "Appearance", "Window title should update to Appearance")

        // Switch to Privacy
        settingsWC.selectCategory(.privacy)
        assertEqual(settingsWC.currentCategory, .privacy, "Active category should switch to Privacy")
        assertEqual(settingsWC.window?.title, "Privacy", "Window title should update to Privacy")

        // Switch back to General
        settingsWC.selectCategory(.general)
        assertEqual(settingsWC.currentCategory, .general, "Active category should switch back to General")
        assertEqual(settingsWC.window?.title, "General", "Window title should update to General")
        print("✓ SettingsWindowController & Sidebar Categorization tests passed")

        print("All Sansara Unit Tests Passed Successfully! 🎉")
    }
}
