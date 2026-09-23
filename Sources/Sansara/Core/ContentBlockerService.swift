import Foundation
import WebKit

/// Zero-overhead native content blocker utilizing WebKit's declarative C++ bytecode engine.
/// Blocks trackers, analytics beacons, telemetry, and high-impact ad networks without JS execution overhead.
public final class ContentBlockerService {

    public static let shared = ContentBlockerService()

    private let ruleListIdentifier = "SansaraPrivacyShieldRules"
    private var compiledRuleList: WKContentRuleList?
    private var isCompiling = false
    private var pendingConfigurations: [WKWebViewConfiguration] = []
    private let lock = NSLock()

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

        // Declarative rule set targeting pervasive cross-site trackers, analytics, and telemetry
        let trackerDomains = [
            "doubleclick\\\\.net",
            "google-analytics\\\\.com",
            "googletagservices\\\\.com",
            "scorecardresearch\\\\.com",
            "quantserve\\\\.com",
            "adnxs\\\\.com",
            "moatads\\\\.com",
            "criteo\\\\.com",
            "hotjar\\\\.com",
            "segment\\\\.io",
            "mixpanel\\\\.com"
        ]

        var ruleObjects: [String] = trackerDomains.map { domain in
            """
            {
                "trigger": { "url-filter": ".*\(domain).*" },
                "action": { "type": "block" }
            }
            """
        }
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
                        config.userContentController.add(ruleList)
                    }
                }
            } else {
                self.lock.unlock()
            }
        }
    }

    /// Attaches the native privacy shield to a WKWebViewConfiguration
    public func applyShield(to configuration: WKWebViewConfiguration) {
        lock.lock()
        if let ruleList = compiledRuleList {
            lock.unlock()
            DispatchQueue.main.async {
                configuration.userContentController.add(ruleList)
            }
        } else {
            pendingConfigurations.append(configuration)
            lock.unlock()
            compileRulesIfNeeded()
        }
    }
}
