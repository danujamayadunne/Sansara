import AppKit
import WebKit

public protocol BrowserTabDelegate: AnyObject {
    func browserTabDidUpdate(_ tab: BrowserTab)
    func browserTab(_ tab: BrowserTab, requestOpenNewTabWith request: URLRequest)
}

/// Represents an individual browser tab with browsing state and associated WKWebView.
public final class BrowserTab: NSObject {

    public let id: UUID
    public weak var delegate: BrowserTabDelegate?

    public private(set) var title: String = "New Tab"
    public private(set) var url: URL?
    public private(set) var favicon: NSImage = FaviconService.defaultIcon
    public private(set) var isLoading: Bool = false
    public private(set) var estimatedProgress: Double = 0.0
    public private(set) var canGoBack: Bool = false
    public private(set) var canGoForward: Bool = false
    public private(set) var errorMessage: String?

    /// Whether this tab is currently showing the minimal new tab page
    public var isNewTabPage: Bool {
        return url == nil
    }

    /// Lazily initialized WKWebView instance
    private var _webView: WKWebView?
    public var webView: WKWebView {
        if let existing = _webView {
            return existing
        }
        let created = createWebView()
        _webView = created
        return created
    }

    /// Check if webView is already instantiated without creating it
    public var hasInstantiatedWebView: Bool {
        return _webView != nil
    }

    // KVO Observations
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var backObservation: NSKeyValueObservation?
    private var forwardObservation: NSKeyValueObservation?

    public init(id: UUID = UUID(), initialURL: URL? = nil) {
        self.id = id
        self.url = initialURL
        super.init()

        if let initialURL = initialURL {
            self.title = initialURL.host ?? "Loading…"
            load(url: initialURL)
        }
    }

    deinit {
        cleanup()
    }

    public func cleanup() {
        stopObservers()
        _webView?.stopLoading()
        _webView?.navigationDelegate = nil
        _webView?.uiDelegate = nil
        _webView?.removeFromSuperview()
        _webView = nil
    }

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.uiDelegate = self

        setupObservers(for: webView)
        return webView
    }

    private func setupObservers(for webView: WKWebView) {
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            let newTitle = view.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newTitle = newTitle, !newTitle.isEmpty {
                self.title = newTitle
            } else if let host = self.url?.host {
                self.title = host
            } else {
                self.title = "New Tab"
            }
            self.delegate?.browserTabDidUpdate(self)
        }

        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            self.url = view.url
            if let url = view.url {
                FaviconService.shared.getFavicon(for: url) { [weak self] image in
                    guard let self = self else { return }
                    self.favicon = image
                    self.delegate?.browserTabDidUpdate(self)
                }
            }
            self.delegate?.browserTabDidUpdate(self)
        }

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            self.estimatedProgress = view.estimatedProgress
            self.delegate?.browserTabDidUpdate(self)
        }

        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            self.isLoading = view.isLoading
            self.delegate?.browserTabDidUpdate(self)
        }

        backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            self.canGoBack = view.canGoBack
            self.delegate?.browserTabDidUpdate(self)
        }

        forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
            guard let self = self else { return }
            self.canGoForward = view.canGoForward
            self.delegate?.browserTabDidUpdate(self)
        }
    }

    private func stopObservers() {
        titleObservation?.invalidate()
        titleObservation = nil
        urlObservation?.invalidate()
        urlObservation = nil
        progressObservation?.invalidate()
        progressObservation = nil
        loadingObservation?.invalidate()
        loadingObservation = nil
        backObservation?.invalidate()
        backObservation = nil
        forwardObservation?.invalidate()
        forwardObservation = nil
    }

    // MARK: - Navigation Actions

    public func load(url: URL) {
        self.url = url
        self.errorMessage = nil
        if title == "New Tab" {
            title = url.host ?? "Loading…"
        }
        FaviconService.shared.getFavicon(for: url) { [weak self] image in
            guard let self = self else { return }
            self.favicon = image
            self.delegate?.browserTabDidUpdate(self)
        }
        let request = URLRequest(url: url)
        webView.load(request)
        delegate?.browserTabDidUpdate(self)
    }

    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    public func reload() {
        if errorMessage != nil, let url = url {
            load(url: url)
        } else {
            webView.reload()
        }
    }

    public func stopLoading() {
        webView.stopLoading()
    }
}

// MARK: - WKNavigationDelegate
extension BrowserTab: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorMessage = nil
        delegate?.browserTabDidUpdate(self)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorMessage = nil
        if webView.url?.host != nil {
            FaviconService.shared.getFavicon(for: webView.url) { [weak self] image in
                guard let self = self else { return }
                self.favicon = image
                self.delegate?.browserTabDidUpdate(self)
            }
        }
        delegate?.browserTabDidUpdate(self)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Ignore user-cancelled loads (error code -999)
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        errorMessage = error.localizedDescription
        delegate?.browserTabDidUpdate(self)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        errorMessage = error.localizedDescription
        delegate?.browserTabDidUpdate(self)
    }
}

// MARK: - WKUIDelegate
extension BrowserTab: WKUIDelegate {

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Open target="_blank" links in a new tab instead of spawning a new window
        if navigationAction.targetFrame == nil {
            delegate?.browserTab(self, requestOpenNewTabWith: navigationAction.request)
        }
        return nil
    }
}
