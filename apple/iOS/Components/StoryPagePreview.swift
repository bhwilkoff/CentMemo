#if os(iOS) || os(macOS)
import SwiftUI
import WebKit

/// The page a reader will see, drawn by the site's own code (js/money/story-page.js,
/// bundled). It loads nothing from the network.
struct StoryPagePreview {
    let draft: StoryLinkDraft

    static let html: String = {
        func read(_ name: String, _ ext: String) -> String {
            Bundle.main.url(forResource: name, withExtension: ext).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        return """
        <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>\(read("story-page", "css"))
        html, body { margin: 0; min-height: 100%; } body { display: flex; min-height: 100vh; } #page { flex: 1; min-width: 0; --sp-display: ui-serif, Georgia, serif; }</style></head>
        <body><main id="page" class="sp"></main><script>\(read("story-page", "js"))</script></body></html>
        """
    }()

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        private var ready = false
        private var waiting: String?
        private var shown: String?

        func make(_ draft: StoryLinkDraft) -> WKWebView {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            let web = WKWebView(frame: .zero, configuration: config)
            web.navigationDelegate = self
            #if os(iOS)
            web.isOpaque = false
            web.backgroundColor = .clear
            web.accessibilityIdentifier = "link-page"
            #endif
            web.loadHTMLString(StoryPagePreview.html, baseURL: nil)
            draw(draft, on: web)
            return web
        }
        func draw(_ draft: StoryLinkDraft, on web: WKWebView) {
            guard let data = try? JSONEncoder().encode(draft.preview), let json = String(data: data, encoding: .utf8), json != shown else { return }
            guard ready else { waiting = json; return }
            shown = json
            Self.render(json, on: web)
        }
        /// Not callAsyncJavaScript: its Swift form lives in a library iOS 18 does not have,
        /// and the app then cannot start there (seen on the iOS 18.5 simulator, 2026-11-25).
        private static func render(_ json: String, on web: WKWebView) {
            guard let data = try? JSONEncoder().encode(json), let literal = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("CentStory.render(document.getElementById('page'), JSON.parse(\(literal))); null", completionHandler: nil)
        }
        func webView(_ web: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            guard let json = waiting else { return }
            waiting = nil; shown = json
            Self.render(json, on: web)
        }
        func webView(_ web: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            action.request.url?.scheme == "about" ? .allow : .cancel
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
}

#if os(macOS)
extension StoryPagePreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { context.coordinator.make(draft) }
    func updateNSView(_ web: WKWebView, context: Context) { context.coordinator.draw(draft, on: web) }
}
#else
extension StoryPagePreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { context.coordinator.make(draft) }
    func updateUIView(_ web: WKWebView, context: Context) { context.coordinator.draw(draft, on: web) }
}
#endif
#endif
