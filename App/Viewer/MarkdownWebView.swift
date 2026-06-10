import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    var markdown: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "ready")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // let CSS paint bg, avoid white flash
        context.coordinator.webView = webView

        if let index = WebResources.indexURL(), let dir = WebResources.directory() {
            webView.loadFileURL(index, allowingReadAccessTo: dir)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(markdown)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private var ready = false
        private var pending: String?
        private var lastRendered: String?

        func render(_ markdown: String) {
            guard ready else { pending = markdown; return }
            guard markdown != lastRendered else { return }
            lastRendered = markdown
            let js = "window.renderMarkdown(\(WebResources.jsLiteral(markdown)));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ready" else { return }
            ready = true
            if let p = pending { pending = nil; lastRendered = nil; render(p) }
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
