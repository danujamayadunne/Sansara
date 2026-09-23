# Sansara

A minimalist native macOS web browser built from scratch in **Swift**, **AppKit**, and **WKWebView**.

Inspired by Apple's human interface guidelines and modern vertical sidebar tab organization, Sansara is designed to be calm, quiet, and fast with a tiny memory footprint.

---

## Highlights

* **100% Native**: Pure Swift and AppKit. Zero third-party frameworks, zero Electron/Chromium overhead.
* **Lightweight**: Binary size ~317 KB. Instant startup and negligible memory footprint.
* **Arc-Inspired Sidebar**: Vertical tab list on the left with clean title truncation, favicons, hover-revealed close buttons, and tab context menus.
* **Quiet New Tab Page**: No ads, news feeds, sponsored content, or widgets. Just a clean, centered Google search and URL entry.
* **Smart URL Resolution**: Automatically detects domain names, localhost ports, and search queries (directing queries to Google).
* **Keyboard First**: Full native macOS menu shortcuts for tabs, navigation, and sidebar toggling.
* **System Color Adaptation**: Seamlessly adapts to macOS Light and Dark appearance modes.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>⌘</kbd> + <kbd>T</kbd> | New Tab |
| <kbd>⌘</kbd> + <kbd>W</kbd> | Close Current Tab |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>T</kbd> | Reopen Closed Tab |
| <kbd>⌘</kbd> + <kbd>L</kbd> | Focus Address Bar / Search |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Reload Current Page |
| <kbd>⌘</kbd> + <kbd>[</kbd> | Navigate Back |
| <kbd>⌘</kbd> + <kbd>]</kbd> | Navigate Forward |
| <kbd>⌘</kbd> + <kbd>1</kbd> .. <kbd>9</kbd> | Switch to Tab 1–9 |
| <kbd>⌃</kbd> + <kbd>⌘</kbd> + <kbd>S</kbd> | Toggle Sidebar |

---

## Building & Running

### Requirements
* macOS 14.0 (Sonoma) or later
* Xcode 15+ command line tools (`swiftc`)

### Compile and Run
To build the application bundle:

```bash
./scripts/build.sh
```

To launch the compiled app:

```bash
open build/Sansara.app
```

To run the unit test suite:

```bash
./scripts/test.sh
```

---

## Architecture Overview

```text
Sources/Sansara/
├── App/
│   └── AppDelegate.swift           # Menu bar items and app lifecycle
├── Core/
│   ├── BrowserTab.swift            # Tab state model, lazy WKWebView, KVO observers
│   ├── TabManager.swift            # Central tab coordinator, history stack
│   ├── URLHelper.swift             # URL heuristics and Google search routing
│   └── FaviconService.swift        # Favicon resolution and host-based caching
├── UI/
│   ├── Content/
│   │   └── BrowserContentViewController.swift # Coordinates navigation bar & content
│   ├── Navigation/
│   │   └── NavigationBarView.swift # Minimal back/forward/reload, address bar, progress bar
│   ├── NewTab/
│   │   └── NewTabView.swift        # Centered Google search field
│   ├── Sidebar/
│   │   ├── SidebarViewController.swift # Vertical tabs list, "+ New Tab" button, context menu
│   │   └── TabItemView.swift       # Tab item cell with hover close button & favicon
│   ├── Web/
│   │   └── WebContainerView.swift  # Active WKWebView and native error recovery view
│   └── Window/
│       ├── BrowserSplitViewController.swift # Native split view for sidebar & content
│       └── BrowserWindowController.swift    # FullSizeContentView window setup
└── main.swift                      # Canonical @main entrypoint
```
