import AppKit
import WebKit
import UniformTypeIdentifiers

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Available settings categories displayed in the sidebar
public enum SettingsCategory: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case privacy = "Privacy"

    var iconName: String {
        switch self {
        case .general:
            return "gearshape.fill"
        case .appearance:
            return "circle.lefthalf.filled"
        case .privacy:
            return "hand.raised.fill"
        }
    }
}

/// An Apple-style frosted glass card container with adaptive light/dark translucency
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
        layer?.cornerRadius = 11.0
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
            // Frosted translucent dark glass
            layer?.backgroundColor = NSColor(white: 0.14, alpha: 0.52).cgColor
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        } else {
            // Frosted translucent white glass
            layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.65).cgColor
            layer?.borderColor = NSColor(white: 0.0, alpha: 0.09).cgColor
        }
        layer?.borderWidth = 0.5
    }
}

/// A row inside an inset glass card with black and white / monochrome icon and background
private final class SettingsRowView: NSView {

    private let squircleBox = NSBox()
    private let iconView = NSImageView()

    init(
        iconName: String,
        title: String,
        subtitle: String,
        control: NSView,
        showDivider: Bool = true
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // Squircle Icon Container (Monochrome Black & White)
        squircleBox.boxType = .custom
        squircleBox.cornerRadius = 6.5
        squircleBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(squircleBox)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)?.withSymbolConfiguration(symbolConfig)
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
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
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
            divider.fillColor = NSColor.separatorColor.withAlphaComponent(0.20)
            divider.translatesAutoresizingMaskIntoConstraints = false
            addSubview(divider)

            NSLayoutConstraint.activate([
                divider.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: trailingAnchor),
                divider.bottomAnchor.constraint(equalTo: bottomAnchor),
                divider.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }

        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            // Dark mode: Deep black squircle with subtle border & crisp white icon
            squircleBox.fillColor = NSColor(white: 0.10, alpha: 0.75)
            squircleBox.borderColor = NSColor(white: 1.0, alpha: 0.18)
            squircleBox.borderWidth = 0.5
            iconView.contentTintColor = .white
        } else {
            // Light mode: Clean white squircle with subtle border & deep black icon
            squircleBox.fillColor = NSColor(white: 1.0, alpha: 0.88)
            squircleBox.borderColor = NSColor(white: 0.0, alpha: 0.12)
            squircleBox.borderWidth = 0.5
            iconView.contentTintColor = .black
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// An interactive sidebar category row with monochrome black & white squircle icon, label, and hover/selection pill
private final class SidebarCategoryItemView: NSView {

    let category: SettingsCategory
    var onClick: ((SettingsCategory) -> Void)?

    var isSelected: Bool = false {
        didSet {
            updateVisualState()
        }
    }

    private var isHovered: Bool = false {
        didSet {
            updateVisualState()
        }
    }

    private let backgroundBox = NSBox()
    private let squircleBox = NSBox()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    init(category: SettingsCategory) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        backgroundBox.boxType = .custom
        backgroundBox.borderWidth = 0
        backgroundBox.cornerRadius = 7.0
        backgroundBox.fillColor = .clear
        backgroundBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundBox)

        squircleBox.boxType = .custom
        squircleBox.cornerRadius = 5.5
        squircleBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(squircleBox)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 11.5, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: category.iconName, accessibilityDescription: category.rawValue)?.withSymbolConfiguration(symbolConfig)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        squircleBox.addSubview(iconView)

        titleLabel.stringValue = category.rawValue
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),

            backgroundBox.topAnchor.constraint(equalTo: topAnchor),
            backgroundBox.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBox.trailingAnchor.constraint(equalTo: trailingAnchor),

            squircleBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            squircleBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            squircleBox.widthAnchor.constraint(equalToConstant: 22),
            squircleBox.heightAnchor.constraint(equalToConstant: 22),

            iconView.centerXAnchor.constraint(equalTo: squircleBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: squircleBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13),

            titleLabel.leadingAnchor.constraint(equalTo: squircleBox.trailingAnchor, constant: 9),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])

        updateVisualState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        backgroundBox.fillColor = isDark ? NSColor(white: 1.0, alpha: 0.18) : NSColor(white: 0.0, alpha: 0.12)
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            onClick?(category)
        }
        updateVisualState()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateVisualState()
    }

    private func updateVisualState() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isSelected {
            // Selected capsule
            backgroundBox.fillColor = isDark ? NSColor(white: 1.0, alpha: 0.14) : NSColor(white: 0.0, alpha: 0.08)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .labelColor

            // High contrast monochrome icon
            if isDark {
                squircleBox.fillColor = .white
                squircleBox.borderColor = .clear
                squircleBox.borderWidth = 0
                iconView.contentTintColor = .black
            } else {
                squircleBox.fillColor = .black
                squircleBox.borderColor = .clear
                squircleBox.borderWidth = 0
                iconView.contentTintColor = .white
            }
        } else if isHovered {
            backgroundBox.fillColor = isDark ? NSColor(white: 1.0, alpha: 0.07) : NSColor(white: 0.0, alpha: 0.04)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = .labelColor

            if isDark {
                squircleBox.fillColor = NSColor(white: 0.16, alpha: 0.8)
                squircleBox.borderColor = NSColor(white: 1.0, alpha: 0.20)
                squircleBox.borderWidth = 0.5
                iconView.contentTintColor = .white
            } else {
                squircleBox.fillColor = NSColor(white: 1.0, alpha: 0.85)
                squircleBox.borderColor = NSColor(white: 0.0, alpha: 0.14)
                squircleBox.borderWidth = 0.5
                iconView.contentTintColor = .black
            }
        } else {
            backgroundBox.fillColor = .clear
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            titleLabel.textColor = .secondaryLabelColor

            if isDark {
                squircleBox.fillColor = NSColor(white: 0.10, alpha: 0.60)
                squircleBox.borderColor = NSColor(white: 1.0, alpha: 0.12)
                squircleBox.borderWidth = 0.5
                iconView.contentTintColor = .white
            } else {
                squircleBox.fillColor = NSColor(white: 1.0, alpha: 0.65)
                squircleBox.borderColor = NSColor(white: 0.0, alpha: 0.10)
                squircleBox.borderWidth = 0.5
                iconView.contentTintColor = .black
            }
        }
    }
}

public final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - State
    public private(set) var currentCategory: SettingsCategory = .general
    private var sidebarItemViews: [SettingsCategory: SidebarCategoryItemView] = [:]

    // MARK: - Navigation & Layout Views
    private let contentScrollView = NSScrollView()
    private let documentView = FlippedView()
    private var generalContainer: NSStackView!
    private var appearanceContainer: NSStackView!
    private var privacyContainer: NSStackView!
    private var activeBottomConstraint: NSLayoutConstraint?

    // MARK: - Controls
    private let searchEnginePopUp = NSPopUpButton()
    private let newTabSegment = NSSegmentedControl(labels: ["Blank", "Image"], trackingMode: .selectOne, target: nil, action: nil)
    private let appearanceNewTabSegment = NSSegmentedControl(labels: ["Blank", "Wallpaper"], trackingMode: .selectOne, target: nil, action: nil)
    private let appearanceSegment = NSSegmentedControl(labels: ["System", "Light", "Dark"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentBlockerSwitch = NSSwitch()
    private let tabNapSwitch = NSSwitch()
    private let tabNapThresholdPopUp = NSPopUpButton()
    private let clearHistoryButton = NSButton(title: "Clear…", target: nil, action: nil)
    private let clearCacheButton = NSButton(title: "Clear…", target: nil, action: nil)
    private let uploadWallpaperButton = NSButton(title: "Choose Image…", target: nil, action: nil)
    private let resetWallpaperButton = NSButton(title: "Reset", target: nil, action: nil)
    private let appearanceUploadWallpaperButton = NSButton(title: "Choose Image…", target: nil, action: nil)
    private let appearanceResetWallpaperButton = NSButton(title: "Reset", target: nil, action: nil)

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "General"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 600, height: 440)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        setupUI()
        loadSettings()
        selectCategory(.general)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func showWindow(_ sender: Any?) {
        loadSettings()
        super.showWindow(sender)
    }

    // MARK: - Setup UI

    private func setupUI() {
        guard let window = window else { return }

        // Root Frosted Glass Background covering the entire settings window
        let rootGlassView = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
        rootGlassView.material = .sidebar
        rootGlassView.blendingMode = .behindWindow
        rootGlassView.state = .active
        rootGlassView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootGlassView

        let mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        rootGlassView.addSubview(mainContainer)
        pinToBounds(mainContainer, in: rootGlassView)

        // 1. Sidebar Container (Left column)
        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(sidebarContainer)

        let sidebarVisualEffect = NSVisualEffectView()
        sidebarVisualEffect.material = .sidebar
        sidebarVisualEffect.blendingMode = .behindWindow
        sidebarVisualEffect.state = .active
        sidebarVisualEffect.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarVisualEffect)
        pinToBounds(sidebarVisualEffect, in: sidebarContainer)

        // 2. Vertical Glass Divider
        let divider = NSBox()
        divider.boxType = .custom
        divider.borderWidth = 0
        divider.fillColor = NSColor.separatorColor.withAlphaComponent(0.20)
        divider.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(divider)

        // 3. Content ScrollView (Right column)
        contentScrollView.drawsBackground = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.autohidesScrollers = true
        contentScrollView.automaticallyAdjustsContentInsets = false
        contentScrollView.contentInsets = NSEdgeInsetsZero
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(contentScrollView)

        documentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = documentView

        NSLayoutConstraint.activate([
            // Sidebar
            sidebarContainer.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            sidebarContainer.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 190),

            // Divider
            divider.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            divider.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),

            // Content ScrollView
            contentScrollView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),

            // Document View
            documentView.topAnchor.constraint(equalTo: contentScrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: contentScrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: contentScrollView.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor)
        ])

        setupSidebar(in: sidebarContainer)
        setupDetailViews()
    }

    private func setupSidebar(in sidebarContainer: NSView) {
        let sidebarStack = NSStackView()
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 3
        // Positioned cleanly below macOS traffic lights without excessive blank padding
        sidebarStack.edgeInsets = NSEdgeInsets(top: 36, left: 10, bottom: 14, right: 10)
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarStack)

        NSLayoutConstraint.activate([
            sidebarStack.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebarStack.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor)
        ])

        for category in SettingsCategory.allCases {
            let item = SidebarCategoryItemView(category: category)
            item.onClick = { [weak self] selectedCategory in
                self?.selectCategory(selectedCategory)
            }
            sidebarItemViews[category] = item
            sidebarStack.addArrangedSubview(item)
            item.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor, constant: -20).isActive = true
        }
    }

    private func setupDetailViews() {
        generalContainer = setupGeneralCategory()
        appearanceContainer = setupAppearanceCategory()
        privacyContainer = setupPrivacyCategory()

        for container in [generalContainer!, appearanceContainer!, privacyContainer!] {
            documentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: documentView.topAnchor),
                container.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: documentView.trailingAnchor)
            ])
        }
    }

    // MARK: - Category Setup

    private func setupGeneralCategory() -> NSStackView {
        let container = createCategoryContainer()

        // Category Header
        container.addArrangedSubview(createCategoryTitle("General"))

        // Section 1: Search & Browsing
        container.addArrangedSubview(createSectionHeader("SEARCH & BROWSING"))

        searchEnginePopUp.removeAllItems()
        for engine in SearchEngine.allCases {
            searchEnginePopUp.addItem(withTitle: engine.rawValue)
        }
        searchEnginePopUp.target = self
        searchEnginePopUp.action = #selector(searchEngineChanged)

        newTabSegment.target = self
        newTabSegment.action = #selector(newTabModeChanged(_:))

        let rowSearch = SettingsRowView(
            iconName: "magnifyingglass",
            title: "Default Search Engine",
            subtitle: "Search provider used for address bar queries",
            control: searchEnginePopUp,
            showDivider: true
        )

        let rowNewTab = SettingsRowView(
            iconName: "safari",
            title: "New Tab Page",
            subtitle: "Page displayed when opening a fresh tab",
            control: newTabSegment,
            showDivider: true
        )

        uploadWallpaperButton.bezelStyle = .rounded
        uploadWallpaperButton.target = self
        uploadWallpaperButton.action = #selector(uploadWallpaperClicked)

        resetWallpaperButton.bezelStyle = .rounded
        resetWallpaperButton.target = self
        resetWallpaperButton.action = #selector(resetWallpaperClicked)

        let wallpaperButtonsStack = NSStackView(views: [resetWallpaperButton, uploadWallpaperButton])
        wallpaperButtonsStack.orientation = .horizontal
        wallpaperButtonsStack.spacing = 8

        let rowCustomWallpaper = SettingsRowView(
            iconName: "photo",
            title: "Custom Wallpaper",
            subtitle: "Choose an image from your Mac for the start page",
            control: wallpaperButtonsStack,
            showDivider: false
        )

        let searchCard = createCard(rows: [rowSearch, rowNewTab, rowCustomWallpaper])
        addCard(searchCard, to: container)

        // Section 2: Performance
        container.addArrangedSubview(createSectionHeader("PERFORMANCE"))

        tabNapSwitch.target = self
        tabNapSwitch.action = #selector(tabNapToggled)

        tabNapThresholdPopUp.removeAllItems()
        let timeoutOptions: [(title: String, minutes: Int)] = [
            ("5 minutes", 5),
            ("15 minutes", 15),
            ("30 minutes", 30),
            ("1 hour", 60)
        ]
        for opt in timeoutOptions {
            tabNapThresholdPopUp.addItem(withTitle: opt.title)
            tabNapThresholdPopUp.lastItem?.tag = opt.minutes
        }
        tabNapThresholdPopUp.target = self
        tabNapThresholdPopUp.action = #selector(tabNapThresholdChanged)

        let rowTabNap = SettingsRowView(
            iconName: "leaf.fill",
            title: "Tab Nap Memory Guard",
            subtitle: "Suspend inactive tabs to conserve Apple Silicon RAM",
            control: tabNapSwitch,
            showDivider: true
        )

        let rowTimeout = SettingsRowView(
            iconName: "timer",
            title: "Inactivity Timeout",
            subtitle: "Duration before background tabs are put to sleep",
            control: tabNapThresholdPopUp,
            showDivider: false
        )

        let perfCard = createCard(rows: [rowTabNap, rowTimeout])
        addCard(perfCard, to: container)

        return container
    }

    private func setupAppearanceCategory() -> NSStackView {
        let container = createCategoryContainer()

        // Category Header
        container.addArrangedSubview(createCategoryTitle("Appearance"))

        // Section 1: Theme
        container.addArrangedSubview(createSectionHeader("THEME"))

        appearanceSegment.target = self
        appearanceSegment.action = #selector(appearanceChanged)

        let rowAppearance = SettingsRowView(
            iconName: "circle.lefthalf.filled",
            title: "Theme Mode",
            subtitle: "Adapt automatically to macOS or lock appearance",
            control: appearanceSegment,
            showDivider: false
        )

        let appearanceCard = createCard(rows: [rowAppearance])
        addCard(appearanceCard, to: container)

        // Section 2: Start Page
        container.addArrangedSubview(createSectionHeader("START PAGE"))

        appearanceNewTabSegment.target = self
        appearanceNewTabSegment.action = #selector(newTabModeChanged(_:))

        let rowStartPage = SettingsRowView(
            iconName: "photo.fill",
            title: "Start Page Layout",
            subtitle: "Display curated wallpaper photography or minimal blank view",
            control: appearanceNewTabSegment,
            showDivider: true
        )

        appearanceUploadWallpaperButton.bezelStyle = .rounded
        appearanceUploadWallpaperButton.target = self
        appearanceUploadWallpaperButton.action = #selector(uploadWallpaperClicked)

        appearanceResetWallpaperButton.bezelStyle = .rounded
        appearanceResetWallpaperButton.target = self
        appearanceResetWallpaperButton.action = #selector(resetWallpaperClicked)

        let appearanceWallpaperButtonsStack = NSStackView(views: [appearanceResetWallpaperButton, appearanceUploadWallpaperButton])
        appearanceWallpaperButtonsStack.orientation = .horizontal
        appearanceWallpaperButtonsStack.spacing = 8

        let rowAppearanceCustomWallpaper = SettingsRowView(
            iconName: "photo",
            title: "Custom Wallpaper",
            subtitle: "Choose an image from your Mac for the start page",
            control: appearanceWallpaperButtonsStack,
            showDivider: false
        )

        let startPageCard = createCard(rows: [rowStartPage, rowAppearanceCustomWallpaper])
        addCard(startPageCard, to: container)

        return container
    }

    private func setupPrivacyCategory() -> NSStackView {
        let container = createCategoryContainer()

        // Category Header
        container.addArrangedSubview(createCategoryTitle("Privacy"))

        // Section 1: Protection
        container.addArrangedSubview(createSectionHeader("TRACKING PROTECTION"))

        contentBlockerSwitch.target = self
        contentBlockerSwitch.action = #selector(contentBlockerToggled)

        let rowShield = SettingsRowView(
            iconName: "shield.fill",
            title: "Native Privacy Shield",
            subtitle: "Declaratively block trackers and cross-site telemetry",
            control: contentBlockerSwitch,
            showDivider: false
        )

        let shieldCard = createCard(rows: [rowShield])
        addCard(shieldCard, to: container)

        // Section 2: Data Management
        container.addArrangedSubview(createSectionHeader("DATA MANAGEMENT"))

        clearHistoryButton.bezelStyle = .rounded
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistoryClicked)

        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.target = self
        clearCacheButton.action = #selector(clearCacheClicked)

        let rowHistory = SettingsRowView(
            iconName: "clock.arrow.circlepath",
            title: "Browsing History",
            subtitle: "Permanently erase recorded visits and navigation logs",
            control: clearHistoryButton,
            showDivider: true
        )

        let rowCache = SettingsRowView(
            iconName: "trash.fill",
            title: "Website Data & Cache",
            subtitle: "Remove cached files, cookies, and local web storage",
            control: clearCacheButton,
            showDivider: false
        )

        let dataCard = createCard(rows: [rowHistory, rowCache])
        addCard(dataCard, to: container)

        return container
    }

    // MARK: - Category Selection

    public func selectCategory(_ category: SettingsCategory) {
        currentCategory = category

        // Update sidebar visual state
        for (cat, itemView) in sidebarItemViews {
            itemView.isSelected = (cat == category)
        }

        // Toggle category container visibility
        generalContainer.isHidden = (category != .general)
        appearanceContainer.isHidden = (category != .appearance)
        privacyContainer.isHidden = (category != .privacy)

        // Update documentView bottom constraint to fit active category height
        activeBottomConstraint?.isActive = false
        let activeContainer: NSView
        switch category {
        case .general:
            activeContainer = generalContainer
        case .appearance:
            activeContainer = appearanceContainer
        case .privacy:
            activeContainer = privacyContainer
        }
        let newBottom = activeContainer.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        newBottom.isActive = true
        activeBottomConstraint = newBottom

        // Reset scroll position to top
        contentScrollView.contentView.scroll(to: .zero)
        contentScrollView.reflectScrolledClipView(contentScrollView.contentView)

        // Update window title
        window?.title = category.rawValue
    }

    // MARK: - UI Helpers

    private func createCategoryContainer() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        // Clean compact top inset eliminating excessive blank space
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 28, bottom: 28, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func createCard(rows: [SettingsRowView]) -> SettingsCardView {
        let card = SettingsCardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        pinToBounds(stack, in: card)

        return card
    }

    private func addCard(_ card: SettingsCardView, to container: NSStackView) {
        container.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -56).isActive = true
    }

    private func createCategoryTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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

    // MARK: - Load Settings

    private func loadSettings() {
        let settings = SettingsManager.shared

        // Search engine
        searchEnginePopUp.selectItem(withTitle: settings.searchEngine.rawValue)

        // Appearance
        switch settings.appearanceMode {
        case .system:
            appearanceSegment.selectedSegment = 0
        case .light:
            appearanceSegment.selectedSegment = 1
        case .dark:
            appearanceSegment.selectedSegment = 2
        }

        // New Tab
        let newTabIndex = (settings.newTabPageMode == .image) ? 1 : 0
        newTabSegment.selectedSegment = newTabIndex
        appearanceNewTabSegment.selectedSegment = newTabIndex

        // Switches
        contentBlockerSwitch.state = settings.isContentBlockerEnabled ? .on : .off
        tabNapSwitch.state = settings.tabNapEnabled ? .on : .off

        // Tab Nap Threshold
        if tabNapThresholdPopUp.itemArray.contains(where: { $0.tag == settings.tabNapThreshold }) {
            tabNapThresholdPopUp.selectItem(withTag: settings.tabNapThreshold)
        } else {
            tabNapThresholdPopUp.selectItem(withTitle: "15 minutes")
        }
        tabNapThresholdPopUp.isEnabled = settings.tabNapEnabled

        // Custom Wallpaper
        let hasCustomWallpaper = (settings.customWallpaperPath != nil)
        resetWallpaperButton.isEnabled = hasCustomWallpaper
        appearanceResetWallpaperButton.isEnabled = hasCustomWallpaper
    }

    // MARK: - Actions

    @objc private func uploadWallpaperClicked() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Custom Wallpaper"
        openPanel.prompt = "Select"
        openPanel.allowedContentTypes = [UTType.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        if let window = self.window {
            openPanel.beginSheetModal(for: window) { [weak self] response in
                guard response == .OK, let selectedURL = openPanel.url else { return }
                self?.saveCustomWallpaper(from: selectedURL)
            }
        } else {
            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                saveCustomWallpaper(from: selectedURL)
            }
        }
    }

    private func saveCustomWallpaper(from sourceURL: URL) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let sansaraDir = appSupport.appendingPathComponent("Sansara", isDirectory: true)
        try? FileManager.default.createDirectory(at: sansaraDir, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = sansaraDir.appendingPathComponent("custom_wallpaper.\(ext)")
        try? FileManager.default.removeItem(at: destinationURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            SettingsManager.shared.customWallpaperPath = destinationURL.path
            SettingsManager.shared.newTabPageMode = .image
            loadSettings()
        } catch {
            print("Failed to save custom wallpaper: \(error)")
        }
    }

    @objc private func resetWallpaperClicked() {
        if let currentPath = SettingsManager.shared.customWallpaperPath {
            try? FileManager.default.removeItem(atPath: currentPath)
        }
        SettingsManager.shared.customWallpaperPath = nil
        loadSettings()
    }

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

    @objc private func newTabModeChanged(_ sender: NSSegmentedControl) {
        let mode: NewTabPageMode = sender.selectedSegment == 1 ? .image : .blank
        SettingsManager.shared.newTabPageMode = mode
        newTabSegment.selectedSegment = sender.selectedSegment
        appearanceNewTabSegment.selectedSegment = sender.selectedSegment
    }

    @objc private func contentBlockerToggled() {
        SettingsManager.shared.isContentBlockerEnabled = (contentBlockerSwitch.state == .on)
    }

    @objc private func tabNapToggled() {
        let enabled = (tabNapSwitch.state == .on)
        SettingsManager.shared.tabNapEnabled = enabled
        tabNapThresholdPopUp.isEnabled = enabled
    }

    @objc private func tabNapThresholdChanged() {
        guard let item = tabNapThresholdPopUp.selectedItem else { return }
        SettingsManager.shared.tabNapThreshold = item.tag
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
            FaviconService.shared.clearCache()
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
                FaviconService.shared.clearCache()
                DispatchQueue.main.async {
                    let confirm = NSAlert()
                    confirm.messageText = "Website Data Cleared"
                    confirm.informativeText = "Cache and website cookies have been removed."
                    confirm.runModal()
                }
            }
        }
    }

    // MARK: - Keyboard Navigation

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 125 { // Down arrow
            selectNextCategory()
        } else if event.keyCode == 126 { // Up arrow
            selectPreviousCategory()
        } else {
            super.keyDown(with: event)
        }
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "1":
                selectCategory(.general)
                return true
            case "2":
                selectCategory(.appearance)
                return true
            case "3":
                selectCategory(.privacy)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    private func selectNextCategory() {
        let all = SettingsCategory.allCases
        guard let idx = all.firstIndex(of: currentCategory), idx + 1 < all.count else { return }
        selectCategory(all[idx + 1])
    }

    private func selectPreviousCategory() {
        let all = SettingsCategory.allCases
        guard let idx = all.firstIndex(of: currentCategory), idx - 1 >= 0 else { return }
        selectCategory(all[idx - 1])
    }
}
