# Sansara

A minimalist native macOS web browser built from scratch in **Swift**, **AppKit**, and **WKWebView**.

Designed around modern vertical sidebar tab workflows, Sansara is calm, quiet, private, and exceptionally fast with a tiny memory footprint.

---

## Data & Footprint

| Metric | Sansara | Typical Chromium / Electron Browser |
| :--- | :--- | :--- |
| **App Size** | **~1.2 MB** (standalone binary, zero bloat) | 200 MB – 500 MB |
| **Source Code Modules** | **30 Swift files** (zero external dependencies) | Thousands of dependencies / `node_modules` |
| **Cold Start Time** | **< 200 ms** (instant launch) | 1.5 s – 4.0 s |
| **Baseline Idle Memory** | **~15 MB – 30 MB** | 250 MB – 450 MB |
| **UI Framework** | **100% Native AppKit** | Web / React / Electron shell |
| **Web Rendering Engine** | **WebKit (WKWebView)** | Chromium / Blink / V8 |

---

## Key Features

### 🗂️ Arc-Inspired Sidebar & Tab Groups
* **Vertical Tab Organization**: Keep tabs visible and cleanly organized along the left sidebar with host favicons, page titles, hover-revealed close buttons, and context menus.
* **Color-Coded Tab Groups**: Group related tabs into folders tagged with distinct Apple system colors (Blue, Purple, Pink, Orange, Green, and Graphite).
* **Collapsible Folders**: Collapse inactive groups to keep your workspace decluttered.
* **Drag-and-Drop Reordering**: Rearrange tabs and tab groups naturally with smooth native dragging.
* **Inline Tab Renaming**: Double-click any tab title to assign custom names.
* **Collapsible Sidebar**: Toggle the sidebar at any time (<kbd>⌘</kbd><kbd>S</kbd>) for an immersive, edge-to-edge web canvas.

### 📑 Horizontal Tab Strip
* **Collapsed-Mode Tab Strip**: When the vertical sidebar is hidden, a compact horizontal tab strip dynamically appears at the top of the browser.
* **Draggable Chip Layout**: Drag and reorder tab chips horizontally without opening the sidebar.
* **Quick Navigation Controls**: Seamlessly navigate back, forward, reload, or spawn a new tab with custom micro-interaction hover buttons (`HoverIconButton`).

### 🔍 Live Omnibar & History Match Engine
* **Real-Time History Suggestions**: Type in the centered New Tab search card or the floating command bar (<kbd>⌘</kbd><kbd>L</kbd>) to view instant, ranked matches from your browsing history.
* **Smart Matching & Deduplication**: Ranks matching domain names, URL paths, and page titles with visit-frequency weighting.
* **Keyboard Navigation**: Effortlessly navigate through suggestions with arrow keys (<kbd>↓</kbd>/<kbd>↑</kbd>) and jump directly to any site with <kbd>Return</kbd>.
* **Smart URL Resolution**: Automatically detects domain names, localhost ports, and search queries, directing searches to your chosen engine.

### 🛡️ Native Privacy Shield & Tracker Blocking
* **WebKit Bytecode Content Blocker**: Powered by WebKit's declarative C++ bytecode engine (`ContentBlockerService`) with zero JavaScript execution overhead.
* **Comprehensive Tracker Blocking**: Blocks 40+ pervasive cross-site tracking networks, ad brokers, and telemetry beacons (DoubleClick, Google Analytics, Meta Pixel, Hotjar, Criteo, Segment, Amplitude, and more).
* **Hyperlink Auditing Protection**: Disallows background beacon tracking via `<a ping="...">` attributes.
* **Third-Party Cookie Isolation**: Restricts cross-site third-party cookie access.
* **Anti-Tracking Favicon Resolution**: Strictly validates same-origin and subdomain hosts, blocks cross-origin tracker beacons, and halts external redirects.
* **Apple Handoff Credential Scrubbing**: Sanitizes sensitive credentials (passwords and tokens) from URLs before broadcasting Continuity activities.
* **Local File Scheme Guard**: Strictly prevents remote web content from initiating navigation to local `file://` URLs.

### 🎨 Start Page Customization & Wallpaper Engine
* **Dual Layout Modes**:
  * **Image Mode**: Start page featuring custom user wallpaper photography with a frosted translucent search card.
  * **Blank Mode**: Clean, distraction-free solid background adhering to the system appearance.
* **Custom Wallpaper Chooser**: Select any image file (`.jpg`, `.png`, `.heic`, etc.) directly from your Mac with instant preview and one-click reset to default. Zero bundled image bloat—the browser bundle stays under 1.2 MB.
* **Multi-Engine Search Provider**: Choose between **Google**, **DuckDuckGo**, **Bing**, **Brave**, or **Ecosia**.

### ⚡ Tab Nap Memory Guard
* **Intelligent Tab Suspension**: Automatically suspends inactive background tabs to reduce CPU cycles and conserve Apple Silicon unified memory.
* **Configurable Sleep Thresholds**: Choose inactivity timeouts of 5 minutes, 15 minutes, 30 minutes, or 1 hour.
* **Instant State Restoration**: Sleeping tabs wake and reload their exact state the moment you select them.

### ⚙️ Native Settings, History & Bookmarks Windows
* **Native macOS Preferences Window (<kbd>⌘</kbd><kbd>,</kbd>)**: Multi-category sidebar layout (**General**, **Appearance**, and **Privacy**) crafted with frosted glass cards, hairline dividers, and monochrome squircle iconography.
* **Browsing History Manager (<kbd>⌘</kbd><kbd>Y</kbd>)**: Searchable history interface with visit timestamps and single-click entry deletion.
* **Bookmarks Manager (<kbd>⌥</kbd><kbd>⌘</kbd><kbd>B</kbd>)**: Save bookmarks with <kbd>⌘</kbd><kbd>D</kbd> and manage tagged destinations in a dedicated manager window.
* **One-Click Privacy Eraser**: Instantly clear browsing history, website cache, cookies, and favicon storage.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>⌘</kbd> + <kbd>T</kbd> | New Tab |
| <kbd>⌘</kbd> + <kbd>W</kbd> | Close Current Tab |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>T</kbd> | Reopen Closed Tab |
| <kbd>⌘</kbd> + <kbd>L</kbd> | Focus Address Bar / Command Palette |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Reload Current Page |
| <kbd>⌘</kbd> + <kbd>[</kbd> | Navigate Back |
| <kbd>⌘</kbd> + <kbd>]</kbd> | Navigate Forward |
| <kbd>⌘</kbd> + <kbd>S</kbd> | Toggle Sidebar (Show / Hide) |
| <kbd>⌘</kbd> + <kbd>,</kbd> | Preferences / Settings |
| <kbd>⌘</kbd> + <kbd>Y</kbd> | Show All History |
| <kbd>⌘</kbd> + <kbd>D</kbd> | Bookmark Current Tab |
| <kbd>⌥</kbd> + <kbd>⌘</kbd> + <kbd>B</kbd> | Show Bookmarks Manager |
| <kbd>⌘</kbd> + <kbd>1</kbd> .. <kbd>9</kbd> | Switch to Tab 1–9 |
| <kbd>Esc</kbd> | Dismiss Command Palette / Suggestions Dropdown |
| <kbd>↓</kbd> / <kbd>↑</kbd> | Navigate History & Search Suggestions |
| <kbd>Return</kbd> | Open URL / Search Query / Selected Suggestion |

---

## Building & Running

### Requirements
* macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
* Xcode 15+ command line tools (`swiftc`)

### Compile Application Bundle
To build the native macOS application bundle:

```bash
./scripts/build.sh
```

### Launch Browser
To launch the compiled app:

```bash
open build/Sansara.app
```

### Run Test Suite
To run the automated unit test suite:

```bash
./scripts/test.sh
```

---

## Architecture Overview

Sansara is structured into clean modular layers with zero third-party dependencies:

```text
Sources/Sansara/
├── App/
│   └── AppDelegate.swift               # Application lifecycle, main menu, dynamic history/bookmarks menus
├── Core/
│   ├── BookmarkManager.swift           # Persistent bookmarks store with search, metadata, and storage
│   ├── BrowserTab.swift                # Tab state model, lazy WKWebView, KVO observers, and Tab Nap lifecycle
│   ├── ContentBlockerService.swift     # Declarative WebKit privacy shield, tracker blocking, and ping protection
│   ├── FaviconService.swift            # Safe cross-origin favicon resolution, monogram disc generator, and memory cache
│   ├── HistoryManager.swift            # Visited URL persistence, search, timestamps, and deduplication
│   ├── SearchSuggestionsProvider.swift # Ranked, deduplicated URL and history suggestion match engine
│   ├── SettingsManager.swift           # Preferences coordinator for search engine, wallpaper, appearance, and privacy
│   ├── TabGroup.swift                  # Tab group data structures, color definitions, and persistence
│   ├── TabManager.swift                # Central tab coordinator, history stack, group hierarchy, and reordering
│   └── URLHelper.swift                 # Heuristic URL resolution and dynamic search engine query routing
├── UI/
│   ├── Bookmarks/
│   │   └── BookmarksWindowController.swift # Bookmarks manager window, editor, and item deletion
│   ├── Content/
│   │   ├── BrowserContentViewController.swift # Navigation orchestration, floating command bar, and tab strip
│   │   ├── ContentColors.swift                # Adaptive light/dark palette for content views
│   │   ├── SearchHistoryDropdownView.swift    # Live interactive suggestion dropdown with keyboard selection
│   │   └── TabStripeColors.swift              # Dynamic color palette for horizontal tab chips and borders
│   ├── History/
│   │   └── HistoryWindowController.swift      # Searchable history manager window with entry deletion
│   ├── NewTab/
│   │   └── NewTabView.swift                   # Centered search card, custom wallpaper engine, and live suggestions
│   ├── Settings/
│   │   └── SettingsWindowController.swift     # Frosted glass Settings window with General, Appearance, and Privacy tabs
│   ├── Sidebar/
│   │   ├── FolderItemView.swift               # Tab group folder cell with expand/collapse chevron
│   │   ├── HoverIconButton.swift              # Reusable micro-interaction hover button with symbol styling
│   │   ├── InlineRenameTextField.swift        # In-place double-click text field for tab renaming
│   │   ├── SidebarBackgroundView.swift        # Adaptive translucent sidebar background container
│   │   ├── SidebarViewController.swift        # Vertical tab hierarchy, tab groups, and drag-and-drop coordinator
│   │   ├── TabGroupDialog.swift               # Modal dialog for creating and editing tab groups
│   │   └── TabItemView.swift                  # Tab cell with favicon, audio indicator, and hover close button
│   ├── Web/
│   │   └── WebContainerView.swift             # Active WKWebView container and native error recovery view
│   └── Window/
│       ├── BrowserSplitViewController.swift    # Split view coordinator for seamless sidebar and content division
│       └── BrowserWindowController.swift       # FullSizeContentView window setup, traffic lights, and toolbar actions
└── main.swift                          # Canonical @main entrypoint
```

---

## License

Sansara is open source software released under the [MIT License](LICENSE).

