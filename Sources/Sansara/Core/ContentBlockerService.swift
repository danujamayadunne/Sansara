import Foundation
import WebKit

/// Zero-overhead native content blocker utilizing WebKit's declarative C++ bytecode engine.
/// Blocks pervasive trackers, analytics beacons, telemetry, ad networks, and hyperlink ping auditing.
public final class ContentBlockerService {

    public static let shared = ContentBlockerService()

    private let ruleListIdentifier = "SansaraPrivacyShieldRules"
    private var compiledRuleList: WKContentRuleList?
    private var isCompiling = false
    private var pendingConfigurations: [WKWebViewConfiguration] = []
    private let lock = NSLock()

    /// Curated list of high-impact cross-site tracking and telemetry domains
    public static let trackerDomainList: [String] = [
        // Google Tracking & Advertising
        "doubleclick.net",
        "google-analytics.com",
        "analytics.google.com",
        "googletagmanager.com",
        "googletagservices.com",
        "googleadservices.com",
        "googlesyndication.com",
        "adservice.google.com",
        "googleads.g.doubleclick.net",
        "stats.g.doubleclick.net",

        // Meta / Facebook
        "connect.facebook.net",
        "pixel.facebook.com",
        "analytics.facebook.com",

        // Twitter / X
        "ads-twitter.com",
        "analytics.twitter.com",

        // Microsoft / LinkedIn
        "bat.bing.com",
        "clarity.ms",
        "snap.licdn.com",

        // TikTok & Amazon
        "analytics.tiktok.com",
        "amazon-adsystem.com",

        // Analytics, Telemetry & Session Replay
        "hotjar.com",
        "hotjar.io",
        "criteo.com",
        "criteo.net",
        "segment.io",
        "segment.com",
        "mixpanel.com",
        "amplitude.com",
        "branch.io",
        "appsflyer.com",
        "fullstory.com",
        "chartbeat.com",
        "mouseflow.com",
        "crazyegg.com",
        "newrelic.com",
        "nr-data.net",

        // Ad Networks & Data Brokers
        "scorecardresearch.com",
        "quantserve.com",
        "quantcount.com",
        "adnxs.com",
        "moatads.com",
        "outbrain.com",
        "taboola.com",
        "omtrdc.net",
        "demdex.net",
        "krxd.net",
        "bluekai.com",
        "rubiconproject.com",
        "pubmatic.com",
        "casalemedia.com",
        "openx.net",
        "mc.yandex.ru"
    ]

    /// Helper to test if a hostname matches any known tracker
    public static func isTracker(host: String) -> Bool {
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return trackerDomainList.contains { tracker in
            clean == tracker || clean.hasSuffix("." + tracker)
        }
    }

    private init() {
        compileRulesIfNeeded()
    }

    /// Compiles declarative privacy rules into WebKit bytecode
    public func compileRulesIfNeeded() {
        lock.lock()
        if compiledRuleList != nil || isCompiling {
            lock.unlock()
            return
        }
        isCompiling = true
        lock.unlock()

        // 1. Tracker domain blocking rules
        var ruleObjects: [String] = Self.trackerDomainList.map { domain in
            let escapedDomain = domain.replacingOccurrences(of: ".", with: "\\\\.")
            return """
            {
                "trigger": { "url-filter": ".*\(escapedDomain).*" },
                "action": { "type": "block" }
            }
            """
        }

        // 2. Block Hyperlink Auditing (ping attribute tracking)
        ruleObjects.append("""
        {
            "trigger": { "url-filter": ".*", "resource-type": ["ping"] },
            "action": { "type": "block" }
        }
        """)

        // 3. Block Third-Party Tracking Cookies
        ruleObjects.append("""
        {
            "trigger": { "url-filter": ".*", "load-type": ["third-party"] },
            "action": { "type": "block-cookies" }
        }
        """)

        let rulesJSON = "[\n" + ruleObjects.joined(separator: ",\n") + "\n]"

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: ruleListIdentifier,
            encodedContentRuleList: rulesJSON
        ) { [weak self] ruleList, error in
            guard let self = self else { return }
            self.lock.lock()
            self.isCompiling = false
            if let ruleList = ruleList, error == nil {
                self.compiledRuleList = ruleList
                let pending = self.pendingConfigurations
                self.pendingConfigurations.removeAll()
                self.lock.unlock()

                DispatchQueue.main.async {
                    for config in pending {
                        if SettingsManager.shared.isContentBlockerEnabled {
                            config.userContentController.remove(ruleList)
                            config.userContentController.add(ruleList)
                        }
                    }
                }
            } else {
                self.lock.unlock()
            }
        }
    }

    /// Attaches the native privacy shield to a WKWebViewConfiguration if enabled
    public func applyShield(to configuration: WKWebViewConfiguration) {
        guard SettingsManager.shared.isContentBlockerEnabled else { return }
        lock.lock()
        if let ruleList = compiledRuleList {
            lock.unlock()
            DispatchQueue.main.async {
                configuration.userContentController.remove(ruleList)
                configuration.userContentController.add(ruleList)
            }
        } else {
            pendingConfigurations.append(configuration)
            lock.unlock()
            compileRulesIfNeeded()
        }
    }

    /// Removes the privacy shield rule list from a WKWebViewConfiguration
    public func removeShield(from configuration: WKWebViewConfiguration) {
        lock.lock()
        let ruleList = compiledRuleList
        lock.unlock()
        guard let ruleList = ruleList else { return }
        DispatchQueue.main.async {
            configuration.userContentController.remove(ruleList)
        }
    }
}
