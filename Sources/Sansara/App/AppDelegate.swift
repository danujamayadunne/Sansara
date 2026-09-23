import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    public private(set) var windowController: BrowserWindowController?

    private var historyMenu: NSMenu?
    private var bookmarksMenu: NSMenu?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        // Apply appearance mode from settings
        SettingsManager.shared.applyAppearance()

        let controller = BrowserWindowController()
        self.windowController = controller
        controller.showWindow(self)

        NSApp.activate(ignoringOtherApps: true)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Sansara", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Sansara", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Sansara", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(menuNewTab), keyEquivalent: "t"))
        let reopenItem = NSMenuItem(title: "Reopen Closed Tab", action: #selector(menuReopenClosedTab), keyEquivalent: "t")
        reopenItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(reopenItem)
        fileMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(menuCloseTab), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Open Location…", action: #selector(menuOpenLocation), keyEquivalent: "l"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Reload Page", action: #selector(menuReloadPage), keyEquivalent: "r"))
        viewMenu.addItem(NSMenuItem.separator())
        let toggleSidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(menuToggleSidebar), keyEquivalent: "s")
        toggleSidebarItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(toggleSidebarItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. History Menu
        let historyMenuItem = NSMenuItem()
        let histMenu = NSMenu(title: "History")
        histMenu.delegate = self
        self.historyMenu = histMenu
        historyMenuItem.submenu = histMenu
        mainMenu.addItem(historyMenuItem)

        // 6. Bookmarks Menu
        let bookmarksMenuItem = NSMenuItem()
        let bmarkMenu = NSMenu(title: "Bookmarks")
        bmarkMenu.delegate = self
        self.bookmarksMenu = bmarkMenu
        bookmarksMenuItem.submenu = bmarkMenu
        mainMenu.addItem(bookmarksMenuItem)

        // 7. Navigation Menu
        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigation")
        navMenu.addItem(NSMenuItem(title: "Back", action: #selector(menuBack), keyEquivalent: "["))
        navMenu.addItem(NSMenuItem(title: "Forward", action: #selector(menuForward), keyEquivalent: "]"))
        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)

        // 8. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())

        // Tab switching shortcuts: ⌘1 through ⌘9
        for i in 1...9 {
            let item = NSMenuItem(
                title: "Select Tab \(i)",
                action: #selector(menuSelectTabAtIndex(_:)),
                keyEquivalent: "\(i)"
            )
            item.tag = i - 1
            windowMenu.addItem(item)
        }

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - NSMenuDelegate (Dynamic History & Bookmarks Menus)

    public func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == historyMenu {
            updateHistoryMenu(menu)
        } else if menu == bookmarksMenu {
            updateBookmarksMenu(menu)
        }
    }

    private func updateHistoryMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let showHistoryItem = NSMenuItem(title: "Show All History", action: #selector(menuShowHistory), keyEquivalent: "y")
        menu.addItem(showHistoryItem)

        let clearItem = NSMenuItem(title: "Clear History…", action: #selector(menuClearHistory), keyEquivalent: "")
        menu.addItem(clearItem)

        let reopenItem = NSMenuItem(title: "Reopen Closed Tab", action: #selector(menuReopenClosedTab), keyEquivalent: "t")
        reopenItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(reopenItem)

        menu.addItem(NSMenuItem.separator())

        let recent = HistoryManager.shared.recentHistory(limit: 12)
        if recent.isEmpty {
            let emptyItem = NSMenuItem(title: "No History", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for item in recent {
                let title = item.title.isEmpty ? item.url.absoluteString : item.title
                let truncatedTitle = title.count > 45 ? String(title.prefix(42)) + "…" : title
                let menuItem = NSMenuItem(title: truncatedTitle, action: #selector(menuOpenHistoryItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.url
                menu.addItem(menuItem)
            }
        }
    }

    private func updateBookmarksMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let addBookmarkItem = NSMenuItem(title: "Bookmark This Tab", action: #selector(menuAddBookmark), keyEquivalent: "d")
        menu.addItem(addBookmarkItem)

        let showBookmarksItem = NSMenuItem(title: "Show Bookmarks", action: #selector(menuShowBookmarks), keyEquivalent: "b")
        showBookmarksItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(showBookmarksItem)

        menu.addItem(NSMenuItem.separator())

        let bookmarks = BookmarkManager.shared.allBookmarks()
        if bookmarks.isEmpty {
            let emptyItem = NSMenuItem(title: "No Bookmarks", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for item in bookmarks.prefix(20) {
                let title = item.title.isEmpty ? item.url.absoluteString : item.title
                let truncatedTitle = title.count > 45 ? String(title.prefix(42)) + "…" : title
                let menuItem = NSMenuItem(title: truncatedTitle, action: #selector(menuOpenBookmarkItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.url
                menu.addItem(menuItem)
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func menuOpenSettings() {
        windowController?.showSettings()
    }

    @objc private func menuShowHistory() {
        windowController?.showHistory()
    }

    @objc private func menuClearHistory() {
        windowController?.clearHistory()
    }

    @objc private func menuAddBookmark() {
        windowController?.toggleBookmarkForCurrentTab()
    }

    @objc private func menuShowBookmarks() {
        windowController?.showBookmarks()
    }

    @objc private func menuOpenHistoryItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        windowController?.openURL(url, inNewTab: false)
    }

    @objc private func menuOpenBookmarkItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        windowController?.openURL(url, inNewTab: false)
    }

    @objc private func menuNewTab() {
        windowController?.newTab()
    }

    @objc private func menuCloseTab() {
        windowController?.closeCurrentTab()
    }

    @objc private func menuReopenClosedTab() {
        windowController?.reopenClosedTab()
    }

    @objc private func menuOpenLocation() {
        windowController?.focusAddressBar()
    }

    @objc private func menuReloadPage() {
        windowController?.reloadCurrentPage()
    }

    @objc private func menuBack() {
        windowController?.navigateBack()
    }

    @objc private func menuForward() {
        windowController?.navigateForward()
    }

    @objc private func menuToggleSidebar() {
        windowController?.toggleSidebar()
    }

    @objc private func menuSelectTabAtIndex(_ sender: NSMenuItem) {
        windowController?.selectTab(at: sender.tag)
    }
}
