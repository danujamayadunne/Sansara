import AppKit

final class InlineRenameTextFieldCell: NSTextFieldCell {

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let titleRect = super.drawingRect(forBounds: rect)
        let cellSize = self.cellSize(forBounds: rect)
        let yOffset = floor((rect.height - cellSize.height) / 2.0)
        return NSRect(
            x: titleRect.origin.x,
            y: rect.origin.y + max(0, yOffset),
            width: titleRect.width,
            height: min(rect.height, cellSize.height)
        )
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

/// A lightweight inline text field for renaming tabs directly in the UI.
/// Handles Return key to commit, Escape key to cancel, and losing focus to commit.
public final class InlineRenameTextField: NSTextField, NSTextFieldDelegate {

    public var onCommit: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var minCharacterWidth: Int = 0

    private var isFinishing = false
    private var isSettingUp = false

    public override class var cellClass: AnyClass? {
        get { return InlineRenameTextFieldCell.self }
        set { super.cellClass = newValue }
    }

    public override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        let fontToUse = font ?? NSFont.systemFont(ofSize: 11.5)
        let textWidth = (stringValue as NSString).size(withAttributes: [.font: fontToUse]).width
        if minCharacterWidth > 0 {
            let charWidth = ("M" as NSString).size(withAttributes: [.font: fontToUse]).width
            let minWidth = charWidth * CGFloat(minCharacterWidth)
            return NSSize(width: max(minWidth, textWidth + 8), height: base.height)
        }
        return base
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if !(cell is InlineRenameTextFieldCell) {
            cell = InlineRenameTextFieldCell(textCell: "")
        }
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if !(cell is InlineRenameTextFieldCell) {
            cell = InlineRenameTextFieldCell(textCell: "")
        }
        setup()
    }

    private func setup() {
        delegate = self
        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = false
        backgroundColor = .clear
        focusRingType = .none
        maximumNumberOfLines = 1
        lineBreakMode = .byClipping
        cell?.wraps = false
        cell?.isScrollable = true

        wantsLayer = true
        layer?.borderWidth = 0
        layer?.borderColor = nil
        layer?.masksToBounds = false
    }

    public func beginEditing(initialText: String) {
        isFinishing = false
        isSettingUp = true
        stringValue = initialText
        isHidden = false
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let _ = self.window else { return }
            self.selectText(nil)
            DispatchQueue.main.async { [weak self] in
                self?.isSettingUp = false
            }
        }
    }

    public func commit() {
        guard !isSettingUp, !isFinishing else { return }
        isFinishing = true
        let text = stringValue
        onCommit?(text)
    }

    public func cancel() {
        guard !isFinishing else { return }
        isFinishing = true
        onCancel?()
    }

    // MARK: - NSTextFieldDelegate

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commit()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancel()
            return true
        }
        return false
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
        guard !isSettingUp, !isFinishing else { return }
        commit()
    }
}
