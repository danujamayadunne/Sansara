import AppKit

public protocol NewTabViewDelegate: AnyObject {
    func newTabView(_ view: NewTabView, didSubmitQuery query: String)
}

/// Clean all-white centered search bar for New Tab.
public final class NewTabView: NSView, NSTextFieldDelegate {

    public weak var delegate: NewTabViewDelegate?

    private let searchCard = NSBox()
    private let searchIcon = NSImageView()
    private let searchField = NSTextField()
    private let returnBadge = NSBox()
    private let returnLabel = NSTextField(labelWithString: "↵")

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        // Centered clean white search card
        searchCard.boxType = .custom
        searchCard.borderWidth = 1.0
        searchCard.borderColor = NSColor(white: 0.88, alpha: 1.0)
        searchCard.cornerRadius = 10.0
        searchCard.fillColor = NSColor.white
        searchCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchCard)

        // Magnifying glass icon
        let searchSymbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        searchIcon.image = searchSymbol?.withSymbolConfiguration(config)
        searchIcon.contentTintColor = NSColor(white: 0.5, alpha: 1.0)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchIcon)

        // Return key badge
        returnBadge.boxType = .custom
        returnBadge.borderWidth = 1.0
        returnBadge.borderColor = NSColor(white: 0.9, alpha: 1.0)
        returnBadge.cornerRadius = 5.0
        returnBadge.fillColor = NSColor(white: 0.97, alpha: 1.0)
        returnBadge.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(returnBadge)

        returnLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        returnLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
        returnLabel.translatesAutoresizingMaskIntoConstraints = false
        returnBadge.addSubview(returnLabel)

        // Search text field
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        searchField.textColor = .labelColor
        searchField.placeholderString = "Search Google or enter URL"
        searchField.alignment = .left
        searchField.cell?.wraps = false
        searchField.cell?.isScrollable = true
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchSubmitted)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchCard.centerXAnchor.constraint(equalTo: centerXAnchor),
            searchCard.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            searchCard.widthAnchor.constraint(equalToConstant: 480),
            searchCard.heightAnchor.constraint(equalToConstant: 46),

            searchIcon.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),

            returnBadge.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor, constant: -12),
            returnBadge.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            returnBadge.widthAnchor.constraint(equalToConstant: 22),
            returnBadge.heightAnchor.constraint(equalToConstant: 22),

            returnLabel.centerXAnchor.constraint(equalTo: returnBadge.centerXAnchor),
            returnLabel.centerYAnchor.constraint(equalTo: returnBadge.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: returnBadge.leadingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor)
        ])
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            focus()
        }
    }

    public func focus() {
        searchField.stringValue = ""
        window?.makeFirstResponder(searchField)
    }

    @objc private func searchSubmitted() {
        let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        delegate?.newTabView(self, didSubmitQuery: text)
    }
}
