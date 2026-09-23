import AppKit
import WebKit

public protocol BrowserTabDelegate: AnyObject {
    func browserTabDidUpdate(_ tab: BrowserTab)
    func browserTab(_ tab: BrowserTab, requestOpenNewTabWith request: URLRequest)
}

/// Represents an individual browser tab with browsing state, memory suspension lifecycle,
/// WebContent crash recovery, and associated WKWebView.
public final class BrowserTab: NSObject {

    public let id: UUID
    public weak var delegate: BrowserTabDelegate?

    public var customTitle: String? {
        didSet {
            updateHandoff()
            delegate?.browserTabDidUpdate(self)
        }
    }
    public private(set) var webTitle: String = "New Tab"

    public var title: String {
        get {
            return customTitle ?? webTitle
        }
        set {
            webTitle = newValue
        }
    }

    public func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        customTitle = trimmed.isEmpty ? nil : trimmed
        updateHandoff()
        delegate?.browserTabDidUpdate(self)
    }

    public private(set) var url: URL?
    public private(set) var favicon: NSImage = FaviconService.defaultIcon
    public private(set) var isLoading: Bool = false
    public private(set) var estimatedProgress: Double = 0.0
    public private(set) var canGoBack: Bool = false
    public private(set) var canGoForward: Bool = false
    public private(set) var errorMessage: String?
    public var groupId: UUID?

    /// Tab Nap: Indicates whether this tab has been suspended to conserve Apple Silicon RAM
    public private(set) var isSuspended: Bool = false

    /// Apple Continuity / Handoff activity
    private var handoffActivity: NSUserActivity?

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
        isSuspended = false
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

    public init(id: UUID = UUID(), initialURL: URL? = nil, groupId: UUID? = nil) {
        self.id = id
        self.url = initialURL
        self.groupId = groupId
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
        handoffActivity?.invalidate()
        handoffActivity = nil
        _webView?.stopLoading()
        _webView?.navigationDelegate = nil
        _webView?.uiDelegate = nil
        _webView?.removeFromSuperview()
        _webView = nil
    }

    /// Tab Nap: Frees the WebKit WebContent process and GPU memory while preserving tab metadata
    public func suspend() {
        guard _webView != nil else { return }
        stopObservers()
        _webView?.stopLoading()
        _webView?.navigationDelegate = nil
        _webView?.uiDelegate = nil
        _webView?.removeFromSuperview()
        _webView = nil
        isSuspended = true
        delegate?.browserTabDidUpdate(self)
    }

    /// Wakes a suspended tab and reloads its content
    public func wakeIfNeeded() {
        guard isSuspended else { return }
        isSuspended = false
        if let currentURL = url {
            load(url: currentURL)
        }
    }

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        // Attach native declarative privacy shield
        ContentBlockerService.shared.applyShield(to: config)

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
                if let url = self.url {
                    HistoryManager.shared.updateTitle(for: url, title: newTitle)
                }
            } else if let host = self.url?.host {
                self.title = host
            } else {
                self.title = "New Tab"
            }
            self.updateHandoff()
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
            self.updateHandoff()
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

    // MARK: - Apple Continuity / Handoff

    private func updateHandoff() {
        guard let url = self.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            handoffActivity?.invalidate()
            handoffActivity = nil
            return
        }

        if handoffActivity == nil {
            handoffActivity = NSUserActivity(activityType: "com.apple.Safari.browsing")
        }
        handoffActivity?.title = title
        handoffActivity?.webpageURL = url
        handoffActivity?.becomeCurrent()
    }

    // MARK: - Navigation Actions

    public func load(url: URL) {
        self.url = url
        self.errorMessage = nil
        self.isSuspended = false

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
        updateHandoff()
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
        isSuspended = false
        if errorMessage != nil, let url = url {
            load(url: url)
        } else {
            webView.reload()
        }
    }

    public func stopLoading() {
        _webView?.stopLoading()
    }

    // MARK: - DOM Favicon Resolution

    private func extractDOMFavicon() {
        guard let webView = _webView, let url = webView.url, let host = url.host else { return }

        let js = """
        (function() {
            var links = document.getElementsByTagName('link');
            for (var i = 0; i < links.length; i++) {
                var rel = links[i].getAttribute('rel');
                if (rel && (rel.includes('apple-touch-icon') || rel.includes('icon'))) {
                    return links[i].href;
                }
            }
            return null;
        })()
        """

        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self,
                  let iconHref = result as? String,
                  let iconURL = URL(string: iconHref) else { return }

            var req = URLRequest(url: iconURL)
            req.cachePolicy = .returnCacheDataElseLoad
            req.timeoutInterval = 3.0

            URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
                guard let self = self,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data,
                      let img = NSImage(data: data) else { return }

                FaviconService.shared.cacheFavicon(img, for: host)
                DispatchQueue.main.async {
                    self.favicon = img
                    self.delegate?.browserTabDidUpdate(self)
                }
            }.resume()
        }
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
        extractDOMFavicon()
        if let url = webView.url {
            HistoryManager.shared.addVisit(url: url, title: self.title)
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

    // MARK: - Process Termination Crash Recovery (Jetsam & WebContent crash protection)
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Automatically recover when macOS memory pressure or a WebContent crash terminates the process
        stopObservers()
        _webView?.stopLoading()
        _webView?.navigationDelegate = nil
        _webView?.uiDelegate = nil
        _webView?.removeFromSuperview()
        _webView = nil

        // If tab has an active URL, reload it silently to restore the page
        if let currentURL = self.url {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.load(url: currentURL)
            }
        }
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
