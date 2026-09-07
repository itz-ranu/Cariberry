import AppKit
import Foundation

/// Observes human user activity and returns a status evaluation periodically.
@MainActor
final class ActivityMonitor {

    static let browsers: [String: String] = [
        "com.apple.safari": "Safari",
        "com.google.chrome": "Google Chrome",
        "com.google.chrome.canary": "Google Chrome Canary",
        "company.thebrowser.browser": "Arc",
        "com.brave.browser": "Brave Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.vivaldi.vivaldi": "Vivaldi",
        "com.operasoftware.opera": "Opera",
        "com.kagi.kagimacos": "Orion",
    ]

    var onVerdict: ((Verdict, Double) -> Void)?
    private(set) var lastPage: String = ""
    private(set) var lastTitle: String = ""
    private(set) var automationDenied = false

    private var timer: Timer?
    private let interval: Double = 2.0
    private let queue = DispatchQueue(label: "pup.applescript")
    private let probe = BrowserProbe()
    private var querying = false
    private var queryGeneration = 0
    private var lastBrowserBundle = ""

    func start() {
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        sample()
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func sample() {
        guard Prefs.focusCoaching else { return }
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        let bundle = (front.bundleIdentifier ?? "").lowercased()
        let appName = front.localizedName ?? "something"

        // Exclude our own application from monitoring.
        if bundle == (Bundle.main.bundleIdentifier ?? "com.desktoppup.app").lowercased() { return }

        if let _ = ActivityMonitor.browsers[bundle] {
            if Prefs.browserAwareness {
                if bundle != lastBrowserBundle { lastPage = ""; lastTitle = "" }
                lastBrowserBundle = bundle
                queryBrowser(bundle: bundle)
            } else {
                lastPage = ""; lastTitle = ""
            }
        } else {
            lastPage = ""; lastTitle = ""
            lastBrowserBundle = ""
        }

        let verdict = RuleStore.shared.evaluate(bundle: bundle, appName: appName,
                                                url: lastPage, title: lastTitle)
        onVerdict?(verdict, interval)
    }

    // MARK: AppleScript

    private func queryBrowser(bundle: String) {
        guard !querying else { return }
        guard let source = script(for: bundle) else { return }
        querying = true
        queryGeneration += 1
        let generation = queryGeneration
        let probe = self.probe
        queue.async { [weak self] in
            let (text, denied) = probe.run(bundle: bundle, source: source)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    // a stale completion from a query the timeout below already gave
                    // up on shouldn't clobber whatever's happened since
                    guard let self, self.queryGeneration == generation else { return }
                    self.querying = false
                    if denied { self.automationDenied = true; return }
                    guard !text.isEmpty else { return }
                    self.automationDenied = false
                    let parts = text.components(separatedBy: "\u{241F}")
                    self.lastPage = parts.first?.lowercased() ?? ""
                    self.lastTitle = parts.count > 1 ? parts[1] : ""
                }
            }
        }
        // NSAppleScript has no cancellation API, so a hung/beachballed browser can
        // block `probe.run` indefinitely. Without this, `querying` would stay true
        // forever and every future poll would silently no-op until the app restarts.
        // The generation check means this can't stomp on a newer query that started
        // after this one finally did (or never) return.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.queryGeneration == generation else { return }
            self.querying = false
        }
    }

    private func script(for bundle: String) -> String? {
        let sep = "\u{241F}"
        if bundle == "com.apple.safari" {
            return """
            tell application id "com.apple.Safari"
                if (count of windows) is 0 then return ""
                set theURL to URL of front document
                set theName to name of front document
                return theURL & "\(sep)" & theName
            end tell
            """
        }
        guard let name = ActivityMonitor.browsers[bundle] else { return nil }
        return """
        tell application "\(name)"
            if (count of windows) is 0 then return ""
            set t to active tab of front window
            return (URL of t) & "\(sep)" & (title of t)
        end tell
        """
    }
}

/// Manages the compilation state of AppleScripts. Because compilation is expensive,
/// scripts for each supported browser are built only once and retained in memory.
/// This object is strictly accessed from within ActivityMonitor's serial dispatch queue.
private final class BrowserProbe: @unchecked Sendable {
    private var cache: [String: NSAppleScript] = [:]

    func run(bundle: String, source: String) -> (text: String, denied: Bool) {
        let script: NSAppleScript
        if let cached = cache[bundle] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return ("", false) }
            var compileError: NSDictionary?
            fresh.compileAndReturnError(&compileError)
            cache[bundle] = fresh
            script = fresh
        }
        var err: NSDictionary?
        let result = script.executeAndReturnError(&err)
        let code = err?[NSAppleScript.errorNumber] as? Int
        return (result.stringValue ?? "", code == -1743 || code == -1728)
    }
}
