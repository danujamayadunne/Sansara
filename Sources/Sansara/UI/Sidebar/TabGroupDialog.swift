import AppKit

/// Individual circular color swatch with an Apple-style white checkmark when selected.
private final class ColorSwatchControl: NSControl {

    let color: TabGroupColor
    var isColorSelected: Bool = false {
        didSet {
            if oldValue != isColorSelected {
                needsDisplay = true
            }
        }
    }

    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?

    init(color: TabGroupColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        toolTip = color.rawValue
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 24, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let circleSize: CGFloat = 22.0
        let circleRect = NSRect(
            x: (bounds.width - circleSize) / 2,
            y: (bounds.height - circleSize) / 2,
            width: circleSize,
            height: circleSize
        )

        let circlePath = NSBezierPath(ovalIn: circleRect)
        color.nsColor.setFill()
        circlePath.fill()

        // Subtle hover ring
        if isHovered && !isColorSelected {
            let hoverRing = NSBezierPath(ovalIn: circleRect)
            hoverRing.lineWidth = 1.5
            NSColor(white: 1.0, alpha: 0.4).setStroke()
            hoverRing.stroke()
        }

        // Apple-style checkmark when selected
        if isColorSelected {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            if let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Selected")?.withSymbolConfiguration(symbolConfig) {
                let checkSize = NSSize(width: 12, height: 10)
                let checkRect = NSRect(
                    x: (bounds.width - checkSize.width) / 2,
                    y: (bounds.height - checkSize.height) / 2,
                    width: checkSize.width,
                    height: checkSize.height
                )

                // Pure white checkmark for all colors, dark gray for yellow for contrast
                let checkColor: NSColor = (color == .yellow) ? NSColor(white: 0.15, alpha: 0.95) : .white
                let tintedImage = NSImage(size: checkSize, flipped: false) { rect in
                    checkImage.draw(in: rect)
                    checkColor.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tintedImage.draw(in: checkRect)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    override func updateTrackingAreas() {
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

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
}

/// Helper to display native dialogs for creating, renaming, and coloring tab folders.
public final class TabGroupDialog: NSObject {

    private final class DialogContext: NSObject {
        var selectedColor: TabGroupColor
        var swatches: [ColorSwatchControl] = []

        init(selectedColor: TabGroupColor) {
            self.selectedColor = selectedColor
            super.init()
        }

        @objc func didSelectSwatch(_ sender: ColorSwatchControl) {
            selectedColor = sender.color
            updateSwatchStates()
        }

        func updateSwatchStates() {
            for swatch in swatches {
                swatch.isColorSelected = (swatch.color == selectedColor)
            }
        }
    }

    /// Shows a modal sheet or alert to create or edit a tab group folder.
    public static func show(
        title: String = "New Tab Folder",
        actionButtonTitle: String = "Create",
        initialName: String = "New Folder",
        initialColor: TabGroupColor = .blue,
        completion: @escaping (String?, TabGroupColor?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Enter a name and choose a color for this folder:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: actionButtonTitle)
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 74))

        let nameField = NSTextField(frame: NSRect(x: 0, y: 44, width: 280, height: 24))
        nameField.font = NSFont.systemFont(ofSize: 13)
        nameField.stringValue = initialName
        nameField.placeholderString = "Folder Name"
        nameField.cell?.wraps = false
        nameField.cell?.isScrollable = true
        container.addSubview(nameField)

        let context = DialogContext(selectedColor: initialColor)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        for color in TabGroupColor.allCases {
            let swatch = ColorSwatchControl(color: color)
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.target = context
            swatch.action = #selector(context.didSelectSwatch(_:))

            NSLayoutConstraint.activate([
                swatch.widthAnchor.constraint(equalToConstant: 24),
                swatch.heightAnchor.constraint(equalToConstant: 24)
            ])

            context.swatches.append(swatch)
            stack.addArrangedSubview(swatch)
        }

        context.updateSwatchStates()

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            stack.heightAnchor.constraint(equalToConstant: 26)
        ])

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField
        nameField.selectText(nil)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let trimmedName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = trimmedName.isEmpty ? "Folder" : trimmedName
            completion(finalName, context.selectedColor)
        } else {
            completion(nil, nil)
        }
    }

    /// Prompts the user to rename a folder
    public static func promptRename(
        currentName: String,
        completion: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Rename Folder"
        alert.informativeText = "Enter a new name for this folder:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.font = NSFont.systemFont(ofSize: 13)
        input.stringValue = currentName
        input.cell?.wraps = false
        input.cell?.isScrollable = true
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        input.selectText(nil)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(trimmed.isEmpty ? currentName : trimmed)
        } else {
            completion(nil)
        }
    }

    /// Prompts the user to rename a tab
    public static func promptRenameTab(
        currentName: String,
        completion: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.informativeText = "Enter a custom name for this tab (leave blank to reset to page title):"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.font = NSFont.systemFont(ofSize: 13)
        input.stringValue = currentName
        input.placeholderString = "Tab Name"
        input.cell?.wraps = false
        input.cell?.isScrollable = true
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        input.selectText(nil)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(trimmed)
        } else {
            completion(nil)
        }
    }
}
