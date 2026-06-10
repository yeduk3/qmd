import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    var markdown: String
    @ObservedObject var find: FindController
    var sync: ScrollSync
    /// Source line to scroll to once loaded (set when arriving from the raw view).
    var initialLine: Int?

    func makeCoordinator() -> Coordinator { Coordinator(sync: sync) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "ready")
        config.userContentController.add(context.coordinator, name: "scroll")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // let CSS paint bg, avoid white flash
        context.coordinator.webView = webView
        context.coordinator.pendingLine = initialLine

        if let index = WebResources.indexURL(), let dir = WebResources.directory() {
            webView.loadFileURL(index, allowingReadAccessTo: dir)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(markdown)
        context.coordinator.applyFind(find)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private let sync: ScrollSync
        private var ready = false
        private var pending: String?
        private var lastMarkdown: String?
        private var lastRendered: String?
        var pendingLine: Int?

        // find de-dup
        private var lastVisible = false
        private var lastQuery = ""
        private var lastCase = false
        private var lastNav = 0

        init(sync: ScrollSync) { self.sync = sync }

        func render(_ markdown: String) {
            lastMarkdown = markdown
            guard ready else { pending = markdown; return }
            guard markdown != lastRendered else { return }
            lastRendered = markdown
            webView?.evaluateJavaScript("window.renderMarkdown(\(WebResources.jsLiteral(markdown)));",
                                        completionHandler: nil)
        }

        // MARK: find

        func applyFind(_ find: FindController) {
            guard ready else { return }
            let becameVisible = find.isVisible && !lastVisible
            let queryChanged = find.query != lastQuery || find.caseSensitive != lastCase
            let navChanged = find.navToken != lastNav
            let wasVisible = lastVisible
            lastVisible = find.isVisible
            lastQuery = find.query
            lastCase = find.caseSensitive
            lastNav = find.navToken

            guard find.isVisible else {
                if wasVisible { webView?.evaluateJavaScript("window.getSelection().removeAllRanges();") }
                return
            }
            guard becameVisible || queryChanged || navChanged else { return } // ignore status echoes
            guard !find.query.isEmpty else {
                setStatus(find, "")
                webView?.evaluateJavaScript("window.getSelection().removeAllRanges();")
                return
            }
            let fresh = becameVisible || queryChanged
            let backwards = (navChanged && !fresh) ? find.backwards : false
            performFind(find, backwards: backwards, fresh: fresh)
        }

        private func performFind(_ find: FindController, backwards: Bool, fresh: Bool) {
            let q = find.query, cs = find.caseSensitive
            let js = "window.qmdFind(\(WebResources.jsLiteral(q)), \(cs), \(backwards), \(fresh));"
            webView?.evaluateJavaScript(js) { [weak self] res, _ in
                let found = (res as? Bool) ?? false
                self?.webView?.evaluateJavaScript(
                    "window.qmdCountMatches(\(WebResources.jsLiteral(q)), \(cs));") { c, _ in
                    let n = (c as? Int) ?? Int((c as? Double) ?? 0)
                    if n == 0 && !found { self?.setStatus(find, "Not found") }
                    else { self?.setStatus(find, "\(n) match\(n == 1 ? "" : "es")") }
                }
            }
        }

        private func setStatus(_ find: FindController, _ s: String) {
            if find.status != s { find.status = s }
        }

        // MARK: messages

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                ready = true
                let md = pending ?? lastMarkdown ?? ""
                pending = nil
                lastRendered = nil
                render(md)
                if let line = pendingLine {
                    pendingLine = nil
                    webView?.evaluateJavaScript(
                        "requestAnimationFrame(function(){window.qmdScrollToLine(\(line));});",
                        completionHandler: nil)
                }
            case "scroll":
                let line = (message.body as? Int) ?? Int((message.body as? Double) ?? 0)
                sync.report(line: line, from: .view)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
            // allow loading the bundled renderer; route anything user-initiated outward
            if navigationAction.navigationType == .linkActivated ||
               (url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto") {
                if navigationAction.navigationType == .linkActivated {
                    NSWorkspace.shared.open(url)
                    return decisionHandler(.cancel)
                }
            }
            decisionHandler(.allow)
        }
    }
}
