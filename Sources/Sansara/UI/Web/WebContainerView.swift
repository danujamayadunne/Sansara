import AppKit
import WebKit

/// Container view that displays the active WKWebView or an error state.
public final class WebContainerView: NSView {

    private weak var currentTab: BrowserTab?
    private weak var currentWebView: WKWebView?

    private let errorContainer = NSView()
    private let errorIconView = NSImageView()
    private let errorTitleLabel = NSTextField(labelWithString: "Couldn’t load this page")
    private let errorSubtitleLabel = NSTextField(labelWithString: "")
    private let tryAgainButton = NSButton()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupErrorView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupErrorView()
    }

    private func setupErrorView() {
        wantsLayer = true
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.isHidden = true
        addSubview(errorContainer)

        let wifiSlash = NSImage(systemSymbolName: "wifi.exclamationmark", accessibilityDescription: "Load Error")
        let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .light)
        errorIconView.image = wifiSlash?.withSymbolConfiguration(config)
        errorIconView.contentTintColor = .secondaryLabelColor
        errorIconView.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(errorIconView)

        errorTitleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        errorTitleLabel.textColor = .labelColor
        errorTitleLabel.alignment = .center
        errorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(errorTitleLabel)

        errorSubtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        errorSubtitleLabel.textColor = .secondaryLabelColor
        errorSubtitleLabel.alignment = .center
        errorSubtitleLabel.cell?.wraps = true
        errorSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(errorSubtitleLabel)

        tryAgainButton.title = "Try Again"
        tryAgainButton.bezelStyle = .rounded
        tryAgainButton.target = self
        tryAgainButton.action = #selector(tryAgainClicked)
        tryAgainButton.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(tryAgainButton)

        NSLayoutConstraint.activate([
            errorContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 400),

            errorIconView.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            errorIconView.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorIconView.widthAnchor.constraint(equalToConstant: 48),
            errorIconView.heightAnchor.constraint(equalToConstant: 48),

            errorTitleLabel.topAnchor.constraint(equalTo: errorIconView.bottomAnchor, constant: 16),
            errorTitleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorTitleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),

            errorSubtitleLabel.topAnchor.constraint(equalTo: errorTitleLabel.bottomAnchor, constant: 8),
            errorSubtitleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorSubtitleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),

            tryAgainButton.topAnchor.constraint(equalTo: errorSubtitleLabel.bottomAnchor, constant: 16),
            tryAgainButton.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            tryAgainButton.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor)
        ])
    }

    public func display(tab: BrowserTab?) {
        self.currentTab = tab

        // If switching tabs, remove previous web view from container
        if let currentWV = currentWebView, currentWV != tab?.webView {
            currentWV.removeFromSuperview()
            currentWebView = nil
        }

        guard let tab = tab else {
            errorContainer.isHidden = true
            return
        }

        // Check if there is an error
        if let error = tab.errorMessage {
            errorSubtitleLabel.stringValue = error
            errorContainer.isHidden = false
            currentWebView?.isHidden = true
            return
        }

        errorContainer.isHidden = true

        // Attach WKWebView
        let webView = tab.webView
        webView.underPageBackgroundColor = ContentColors.dynamicBackground
        if webView.superview != self {
            webView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(webView, positioned: .below, relativeTo: errorContainer)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: trailingAnchor),
                webView.topAnchor.constraint(equalTo: topAnchor),
                webView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        webView.isHidden = false
        currentWebView = webView
    }

    @objc private func tryAgainClicked() {
        currentTab?.reload()
    }
}
