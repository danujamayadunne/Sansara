import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {

    public private(set) var windowController: BrowserWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

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

        // 3. Edit Menu (Standard native text editing support)
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

        // 5. History / Navigation Menu
        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigation")
        navMenu.addItem(NSMenuItem(title: "Back", action: #selector(menuBack), keyEquivalent: "["))
        navMenu.addItem(NSMenuItem(title: "Forward", action: #selector(menuForward), keyEquivalent: "]"))
        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)

        // 6. Window Menu
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

    // MARK: - Menu Actions

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
