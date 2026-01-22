import Foundation

#if os(iOS)
import WebKit

enum WebKitProcessPool {
    static let shared = WKProcessPool()
}

final class WebKitPrewarmer {
    static let shared = WebKitPrewarmer()

    private var warmupWebView: WKWebView?

    func warmUp() {
        guard warmupWebView == nil else { return }

        let config = WKWebViewConfiguration()
        config.processPool = WebKitProcessPool.shared

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        warmupWebView = webView

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.warmupWebView = nil
        }
    }
}
#endif
