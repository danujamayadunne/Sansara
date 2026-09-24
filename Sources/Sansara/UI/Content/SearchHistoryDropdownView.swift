import AppKit

// MARK: - Search History Row View

public final class SearchHistoryRowView: NSView {

    public let item: SearchSuggestion
    public let index: Int

    public var isSelected: Bool = false {
        didSet {
            if oldValue != isSelected {
                updateHighlight()
            }
        }
    }

    public var onHover: ((Int) -> Void)?
    public var onClick: ((SearchSuggestion) -> Void)?

    private let backgroundBox = NSBox()
    private let iconView = NSImageView()
    private let textStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private let rightAccessoryStack = NSStackView()
    private let returnBadge = NSBox()
    private let returnLabel = NSTextField(labelWithString: "↵")

    private var trackingArea: NSTrackingArea?

    public init(item: SearchSuggestion, index: Int) {
        self.item = item
        self.index = index
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true

        // Background highlight box
        backgroundBox.boxType = .custom
        backgroundBox.cornerRadius = 6.0
        backgroundBox.borderWidth = 0
        backgroundBox.fillColor = .clear
        backgroundBox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundBox)

        // Leading Icon (Verified Seal or History Clock)
        let iconName = item.kind == .verifiedDomain ? "checkmark.seal.fill" : "clock"
        let iconPointSize: CGFloat = item.kind == .verifiedDomain ? 13.5 : 12.0
        let iconConfig = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: item.kind == .verifiedDomain ? .semibold : .regular)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: item.kind.rawValue)?.withSymbolConfiguration(iconConfig)
        iconView.contentTintColor = item.kind == .verifiedDomain ? .systemBlue : .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        backgroundBox.addSubview(iconView)

        // Text Stack: Title above Display URL
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.distribution = .fill
        textStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundBox.addSubview(textStack)

        // Website / History Title (Line 1, displayed above domain name)
        let displayTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = false
        titleLabel.stringValue = displayTitle.isEmpty ? item.displayURL : displayTitle
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStack.addArrangedSubview(titleLabel)

        // Domain name / Display URL (Line 2)
        urlLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.cell?.wraps = false
        urlLabel.cell?.isScrollable = false
        urlLabel.stringValue = item.displayURL
        urlLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStack.addArrangedSubview(urlLabel)

        // Right accessory: Return key badge (visible on hover / selection)
        rightAccessoryStack.orientation = .horizontal
        rightAccessoryStack.alignment = .centerY
        rightAccessoryStack.spacing = 6
        rightAccessoryStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundBox.addSubview(rightAccessoryStack)

        returnBadge.boxType = .custom
        returnBadge.borderWidth = 0.5
        returnBadge.borderColor = .separatorColor
        returnBadge.cornerRadius = 4.0
        returnBadge.fillColor = .quaternaryLabelColor
        returnBadge.translatesAutoresizingMaskIntoConstraints = false
        returnBadge.isHidden = true

        returnLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        returnLabel.textColor = .secondaryLabelColor
        returnLabel.translatesAutoresizingMaskIntoConstraints = false
        returnBadge.addSubview(returnLabel)

        NSLayoutConstraint.activate([
            returnBadge.widthAnchor.constraint(equalToConstant: 18),
            returnBadge.heightAnchor.constraint(equalToConstant: 18),
            returnLabel.centerXAnchor.constraint(equalTo: returnBadge.centerXAnchor),
            returnLabel.centerYAnchor.constraint(equalTo: returnBadge.centerYAnchor)
        ])
        rightAccessoryStack.addArrangedSubview(returnBadge)

        NSLayoutConstraint.activate([
            backgroundBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            backgroundBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            backgroundBox.topAnchor.constraint(equalTo: topAnchor),
            backgroundBox.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: backgroundBox.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: backgroundBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: rightAccessoryStack.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: backgroundBox.centerYAnchor),

            rightAccessoryStack.trailingAnchor.constraint(equalTo: backgroundBox.trailingAnchor, constant: -8),
            rightAccessoryStack.centerYAnchor.constraint(equalTo: backgroundBox.centerYAnchor)
        ])

        updateHighlight()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHighlight()
    }

    private func updateHighlight() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isSelected {
            backgroundBox.fillColor = isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.06)
            returnBadge.isHidden = false
            returnBadge.borderColor = isDark ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.08)
            returnBadge.fillColor = isDark ? NSColor(white: 1.0, alpha: 0.08) : NSColor(white: 0.0, alpha: 0.05)
            returnBadge.borderWidth = 0.5
            returnLabel.textColor = isDark ? .white : .secondaryLabelColor
        } else {
            backgroundBox.fillColor = .clear
            returnBadge.isHidden = true
        }
    }

    // MARK: - Mouse & Tracking

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(index)
    }

    public override func mouseDown(with event: NSEvent) {
        onClick?(item)
    }
}

// MARK: - Search History Dropdown View

/// Floating suggestions dropdown for URL and search bars, displaying clean URLs with icon badges.
public final class SearchHistoryDropdownView: NSBox {

    public var onSelect: ((SearchSuggestion) -> Void)?

    public private(set) var selectedIndex: Int? = nil {
        didSet {
            updateRowSelection()
        }
    }

    public private(set) var items: [SearchSuggestion] = []

    public var selectedItem: SearchSuggestion? {
        guard let index = selectedIndex, index >= 0, index < items.count else { return nil }
        return items[index]
    }

    private let rowsStack = NSStackView()
    private var rowViews: [SearchHistoryRowView] = []
    private var heightConstraint: NSLayoutConstraint?

    public init() {
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        boxType = .custom
        cornerRadius = 14.0
        borderWidth = 1.0
        isHidden = true

        // Shadow for elevation
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.14
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 10
        layer?.masksToBounds = false

        // Rows Stack
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 2
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)

        let hc = heightAnchor.constraint(equalToConstant: 0)
        hc.priority = .defaultHigh
        hc.isActive = true
        heightConstraint = hc

        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])

        updateAppearance()
    }

    public private(set) var isImageMode: Bool = false

    public func setMode(isImage: Bool) {
        self.isImageMode = isImage
        updateAppearance()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isImageMode {
            fillColor = isDark ? NSColor(white: 0.0, alpha: 0.70) : NSColor(white: 1.0, alpha: 0.85)
        } else {
            fillColor = isDark ? .black : .white
        }
        borderColor = isDark ? NSColor(white: 0.0, alpha: 0.40) : NSColor(white: 0.0, alpha: 0.08)
        borderWidth = 0.5
        for row in rowViews {
            row.viewDidChangeEffectiveAppearance()
        }
    }

    // MARK: - Updates & Population

    public func update(items: [SearchSuggestion]) {
        self.items = items
        selectedIndex = nil

        // Clear existing rows
        for subview in rowsStack.arrangedSubviews {
            rowsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        rowViews.removeAll()

        guard !items.isEmpty else {
            heightConstraint?.constant = 0
            isHidden = true
            return
        }

        // Build new rows
        for (idx, item) in items.enumerated() {
            let rowView = SearchHistoryRowView(item: item, index: idx)
            rowView.translatesAutoresizingMaskIntoConstraints = false

            rowView.onHover = { [weak self] hoverIndex in
                self?.selectedIndex = hoverIndex
            }
            rowView.onClick = { [weak self] clickedItem in
                self?.onSelect?(clickedItem)
            }

            rowsStack.addArrangedSubview(rowView)
            rowViews.append(rowView)

            NSLayoutConstraint.activate([
                rowView.heightAnchor.constraint(equalToConstant: 40),
                rowView.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor)
            ])
        }

        // Top padding (4) + (N * 40) + ((N-1) * 2) + Bottom (4)
        let rowCount = CGFloat(items.count)
        let calculatedHeight = 4.0 + (rowCount * 40.0) + (max(0, rowCount - 1) * 2.0) + 4.0
        heightConstraint?.constant = calculatedHeight
        isHidden = false
    }

    public func hide() {
        isHidden = true
        selectedIndex = nil
        items = []
        for subview in rowsStack.arrangedSubviews {
            rowsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        rowViews.removeAll()
        heightConstraint?.constant = 0
    }

    // MARK: - Selection Navigation

    public func selectNext() {
        guard !items.isEmpty else { return }
        if let current = selectedIndex {
            selectedIndex = min(current + 1, items.count - 1)
        } else {
            selectedIndex = 0
        }
    }

    public func selectPrevious() {
        guard !items.isEmpty else { return }
        if let current = selectedIndex {
            if current == 0 {
                selectedIndex = nil
            } else {
                selectedIndex = current - 1
            }
        }
    }

    private func updateRowSelection() {
        for (idx, row) in rowViews.enumerated() {
            row.isSelected = (idx == selectedIndex)
        }
    }
}
