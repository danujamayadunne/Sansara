import AppKit
import WebKit

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// An Apple-style inset grouped card container with adaptive light/dark appearance
private final class SettingsCardView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10.0
        layer?.masksToBounds = true
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            layer?.backgroundColor = NSColor(white: 0.16, alpha: 1.0).cgColor
            layer?.borderColor = NSColor(white: 0.26, alpha: 0.5).cgColor
        } else {
            layer?.backgroundColor = NSColor.white.cgColor
            layer?.borderColor = NSColor(white: 0.88, alpha: 0.9).cgColor
        }
        layer?.borderWidth = 0.5
    }
}

/// A row inside an inset card matching Apple System Settings layout
private final class SettingsRowView: NSView {

    init(
        iconName: String,
        iconTintColor: NSColor,
        title: String,
        subtitle: String,
        control: NSView,
        showDivider: Bool = true
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // Squircle Icon Container (Apple System Settings style)
        let squircleBox = NSBox()
        squircleBox.boxType = .custom
        squircleBox.borderWidth = 0
        squircleBox.cornerRadius = 6.5
        squircleBox.fillColor = iconTintColor
        squircleBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(squircleBox)

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)?.withSymbolConfiguration(symbolConfig)
        iconView.contentTintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        squircleBox.addSubview(iconView)

        // Labels Stack (Title & Subtitle)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)

        // Trailing Control
        control.translatesAutoresizingMaskIntoConstraints = false
        addSubview(control)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            squircleBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            squircleBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            squircleBox.widthAnchor.constraint(equalToConstant: 28),
            squircleBox.heightAnchor.constraint(equalToConstant: 28),

            iconView.centerXAnchor.constraint(equalTo: squircleBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: squircleBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: squircleBox.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -12),

            control.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            control.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Hairline Inset Divider
        if showDivider {
            let divider = NSBox()
            divider.boxType = .custom
            divider.borderWidth = 0
            divider.fillColor = NSColor.separatorColor.withAlphaComponent(0.35)
            divider.translatesAutoresizingMaskIntoConstraints = false
            addSubview(divider)

            NSLayoutConstraint.activate([
                divider.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: trailingAnchor),
                divider.bottomAnchor.constraint(equalTo: bottomAnchor),
                divider.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private let searchEnginePopUp = NSPopUpButton()
    private let appearanceSegment = NSSegmentedControl(labels: ["System", "Light", "Dark"], trackingMode: .selectOne, target: nil, action: nil)
    private let newTabSegment = NSSegmentedControl(labels: ["Minimal", "Blank"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentBlockerSwitch = NSSwitch()
    private let tabNapSwitch = NSSwitch()
    private let clearHistoryButton = NSButton(title: "Clear…", target: nil, action: nil)
    private let clearCacheButton = NSButton(title: "Clear…", target: nil, action: nil)

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.center()

        super.init(window: window)
        window.delegate = self
        setupUI()
        loadSettings()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }

        let scrollView = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = scrollView

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 20
        rootStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 28, right: 24)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        // Section 1: Search & Browsing
        rootStack.addArrangedSubview(createSectionHeader("SEARCH & BROWSING"))
        let searchCard = SettingsCardView()
        searchCard.translatesAutoresizingMaskIntoConstraints = false

        searchEnginePopUp.removeAllItems()
        for engine in SearchEngine.allCases {
            searchEnginePopUp.addItem(withTitle: engine.rawValue)
        }
        searchEnginePopUp.target = self
        searchEnginePopUp.action = #selector(searchEngineChanged)

        newTabSegment.target = self
        newTabSegment.action = #selector(newTabModeChanged)

        let rowSearch = SettingsRowView(
            iconName: "magnifyingglass",
            iconTintColor: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            title: "Default Search Engine",
            subtitle: "Search provider used for address bar queries",
            control: searchEnginePopUp,
            showDivider: true
        )

        let rowNewTab = SettingsRowView(
            iconName: "safari",
            iconTintColor: NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0),
            title: "New Tab Page",
            subtitle: "Page displayed when opening a fresh tab",
            control: newTabSegment,
            showDivider: false
        )

        let searchCardStack = NSStackView(views: [rowSearch, rowNewTab])
        searchCardStack.orientation = .vertical
        searchCardStack.spacing = 0
        searchCardStack.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchCardStack)
        pinToBounds(searchCardStack, in: searchCard)

        rootStack.addArrangedSubview(searchCard)
        searchCard.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48).isActive = true

        // Section 2: Appearance
        rootStack.addArrangedSubview(createSectionHeader("APPEARANCE"))
        let appearanceCard = SettingsCardView()
        appearanceCard.translatesAutoresizingMaskIntoConstraints = false

        appearanceSegment.target = self
        appearanceSegment.action = #selector(appearanceChanged)

        let rowAppearance = SettingsRowView(
            iconName: "circle.lefthalf.filled",
            iconTintColor: NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0),
            title: "Theme Mode",
            subtitle: "Adapt automatically to macOS or lock appearance",
            control: appearanceSegment,
            showDivider: false
        )

        appearanceCard.addSubview(rowAppearance)
        pinToBounds(rowAppearance, in: appearanceCard)

        rootStack.addArrangedSubview(appearanceCard)
        appearanceCard.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48).isActive = true

        // Section 3: Privacy & Performance
        rootStack.addArrangedSubview(createSectionHeader("PRIVACY & PERFORMANCE"))
        let privacyCard = SettingsCardView()
        privacyCard.translatesAutoresizingMaskIntoConstraints = false

        contentBlockerSwitch.target = self
        contentBlockerSwitch.action = #selector(contentBlockerToggled)

        tabNapSwitch.target = self
        tabNapSwitch.action = #selector(tabNapToggled)

        let rowShield = SettingsRowView(
            iconName: "shield.fill",
            iconTintColor: NSColor(red: 0.19, green: 0.69, blue: 0.78, alpha: 1.0),
            title: "Native Privacy Shield",
            subtitle: "Declaratively block trackers and cross-site telemetry",
            control: contentBlockerSwitch,
            showDivider: true
        )

        let rowTabNap = SettingsRowView(
            iconName: "leaf.fill",
            iconTintColor: NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0),
            title: "Tab Nap Memory Guard",
            subtitle: "Suspend inactive tabs to conserve Apple Silicon RAM",
            control: tabNapSwitch,
            showDivider: false
        )

        let privacyCardStack = NSStackView(views: [rowShield, rowTabNap])
        privacyCardStack.orientation = .vertical
        privacyCardStack.spacing = 0
        privacyCardStack.translatesAutoresizingMaskIntoConstraints = false
        privacyCard.addSubview(privacyCardStack)
        pinToBounds(privacyCardStack, in: privacyCard)

        rootStack.addArrangedSubview(privacyCard)
        privacyCard.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48).isActive = true

        // Section 4: Data Management
        rootStack.addArrangedSubview(createSectionHeader("DATA MANAGEMENT"))
        let dataCard = SettingsCardView()
        dataCard.translatesAutoresizingMaskIntoConstraints = false

        clearHistoryButton.bezelStyle = .rounded
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistoryClicked)

        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.target = self
        clearCacheButton.action = #selector(clearCacheClicked)

        let rowHistory = SettingsRowView(
            iconName: "clock.arrow.circlepath",
            iconTintColor: NSColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0),
            title: "Browsing History",
            subtitle: "Permanently erase recorded visits and navigation logs",
            control: clearHistoryButton,
            showDivider: true
        )

        let rowCache = SettingsRowView(
            iconName: "trash.fill",
            iconTintColor: NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0),
            title: "Website Data & Cache",
            subtitle: "Remove cached files, cookies, and local web storage",
            control: clearCacheButton,
            showDivider: false
        )

        let dataCardStack = NSStackView(views: [rowHistory, rowCache])
        dataCardStack.orientation = .vertical
        dataCardStack.spacing = 0
        dataCardStack.translatesAutoresizingMaskIntoConstraints = false
        dataCard.addSubview(dataCardStack)
        pinToBounds(dataCardStack, in: dataCard)

        rootStack.addArrangedSubview(dataCard)
        dataCard.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48).isActive = true
    }

    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func pinToBounds(_ subview: NSView, in parent: NSView) {
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: parent.topAnchor),
            subview.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }

    private func loadSettings() {
        let settings = SettingsManager.shared

        // Search engine
        searchEnginePopUp.selectItem(withTitle: settings.searchEngine.rawValue)

        // Appearance
        switch settings.appearanceMode {
        case .system: appearanceSegment.selectedSegment = 0
        case .light: appearanceSegment.selectedSegment = 1
        case .dark: appearanceSegment.selectedSegment = 2
        }

        // New Tab
        switch settings.newTabPageMode {
        case .minimal: newTabSegment.selectedSegment = 0
        case .blank: newTabSegment.selectedSegment = 1
        }

        // Switches
        contentBlockerSwitch.state = settings.isContentBlockerEnabled ? .on : .off
        tabNapSwitch.state = settings.tabNapEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func searchEngineChanged() {
        guard let title = searchEnginePopUp.titleOfSelectedItem,
              let engine = SearchEngine(rawValue: title) else { return }
        SettingsManager.shared.searchEngine = engine
    }

    @objc private func appearanceChanged() {
        let mode: AppearanceMode
        switch appearanceSegment.selectedSegment {
        case 1: mode = .light
        case 2: mode = .dark
        default: mode = .system
        }
        SettingsManager.shared.appearanceMode = mode
    }

    @objc private func newTabModeChanged() {
        let mode: NewTabPageMode = newTabSegment.selectedSegment == 1 ? .blank : .minimal
        SettingsManager.shared.newTabPageMode = mode
    }

    @objc private func contentBlockerToggled() {
        SettingsManager.shared.isContentBlockerEnabled = (contentBlockerSwitch.state == .on)
    }

    @objc private func tabNapToggled() {
        SettingsManager.shared.tabNapEnabled = (tabNapSwitch.state == .on)
    }

    @objc private func clearHistoryClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear Browsing History?"
        alert.informativeText = "This will remove all visited pages from your history. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearAll()
        }
    }

    @objc private func clearCacheClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear Cache & Website Data?"
        alert.informativeText = "This will clear cached web files, cookies, and local website data."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All Data")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            let dateFrom = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: dateFrom) {
                DispatchQueue.main.async {
                    let confirm = NSAlert()
                    confirm.messageText = "Website Data Cleared"
                    confirm.informativeText = "Cache and website cookies have been removed."
                    confirm.runModal()
                }
            }
        }
    }
}
