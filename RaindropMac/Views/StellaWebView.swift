// StellaWebView.swift
// Official Stella UI (beta-ai.raindrop.io) in WKWebView with persistent cookies.
// Raindrop’s Stella API requires a web session — OAuth Bearer is not enough.

import SwiftUI
import WebKit

// MARK: - Coordinator store so SwiftUI can call into WKWebView
final class StellaWebBridge: ObservableObject {
    @Published var isLoading = true
    @Published var needsLogin = false
    @Published var pageTitle = "Stella"
    @Published var lastError: String?

    weak var webView: WKWebView?

    func reloadStella(raindropId: Int? = nil) {
        var components = URLComponents(string: "https://beta-ai.raindrop.io/ai")!
        var items: [URLQueryItem] = []
        if let raindropId {
            items.append(URLQueryItem(name: "raindropId", value: "\(raindropId)"))
        }
        items.append(URLQueryItem(name: "closable", value: "false"))
        components.queryItems = items
        guard let url = components.url else { return }
        isLoading = true
        needsLogin = false
        lastError = nil
        webView?.load(URLRequest(url: url))
    }

    func openLogin() {
        // Raindrop web login; after auth cookies work for Stella
        let login = URL(string: "https://app.raindrop.io/account/login?redirect=\(encodedRedirect)")!
        isLoading = true
        needsLogin = false
        webView?.load(URLRequest(url: login))
    }

    private var encodedRedirect: String {
        "https://beta-ai.raindrop.io/ai".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    func goHome() {
        reloadStella()
    }
}

// MARK: - SwiftUI wrapper
struct StellaWebView: NSViewRepresentable {
    @ObservedObject var bridge: StellaWebBridge
    var raindropId: Int?
    var onRaindropLink: ((Int) -> Void)?
    var onCollectionLink: ((Int) -> Void)?
    var onTagLink: ((String) -> Void)?
    var onToolCalled: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge, parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persist cookies across launches
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let uc = config.userContentController
        uc.add(context.coordinator, name: "stellaBridge")

        // Capture postMessage from Stella iframe-style app
        let js = """
        (function() {
          if (window.__stellaBridgeInstalled) return;
          window.__stellaBridgeInstalled = true;
          window.addEventListener('message', function(e) {
            try {
              var d = e.data;
              if (!d || typeof d !== 'object') return;
              if (typeof d.type === 'string' && d.type.indexOf('ai:') === 0) {
                window.webkit.messageHandlers.stellaBridge.postMessage(d);
              }
            } catch (err) {}
          }, false);
        })();
        """
        uc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        bridge.webView = webView
        context.coordinator.attach(webView)

        // Initial load
        DispatchQueue.main.async {
            bridge.reloadStella(raindropId: raindropId)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        bridge.webView = webView
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let bridge: StellaWebBridge
        var parent: StellaWebView

        init(bridge: StellaWebBridge, parent: StellaWebView) {
            self.bridge = bridge
            self.parent = parent
        }

        func attach(_ webView: WKWebView) {
            bridge.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "stellaBridge",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "ai:link-click":
                if let id = body["raindropId"] as? Int {
                    parent.onRaindropLink?(id)
                } else if let id = body["raindropId"] as? String, let n = Int(id) {
                    parent.onRaindropLink?(n)
                } else if let id = body["collectionId"] as? Int {
                    parent.onCollectionLink?(id)
                } else if let id = body["collectionId"] as? String, let n = Int(id) {
                    parent.onCollectionLink?(n)
                } else if let tag = body["tag"] as? String {
                    parent.onTagLink?(tag)
                }
            case "ai:tool-called":
                parent.onToolCalled?()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.bridge.isLoading = true
                self.bridge.lastError = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.bridge.isLoading = false
                self.bridge.pageTitle = webView.title ?? "Stella"
            }
            // Detect login wall
            let check = """
            (function() {
              var t = document.body ? document.body.innerText : '';
              return t.indexOf('Please login') !== -1 || t.indexOf('Sign in') !== -1 && t.length < 800;
            })();
            """
            webView.evaluateJavaScript(check) { result, _ in
                let needs = (result as? Bool) ?? false
                DispatchQueue.main.async {
                    // Only flag login on Stella host, not on account pages mid-flow
                    let host = webView.url?.host ?? ""
                    if host.contains("beta-ai") {
                        self.bridge.needsLogin = needs
                    } else if host.contains("app.raindrop.io") {
                        // After login, app may land on my/ — jump to Stella
                        let path = webView.url?.path ?? ""
                        if path.hasPrefix("/my") || path == "/" {
                            self.bridge.reloadStella(raindropId: self.parent.raindropId)
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.bridge.isLoading = false
                self.bridge.lastError = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.bridge.isLoading = false
                self.bridge.lastError = error.localizedDescription
            }
        }

        // Allow Stella popups / OAuth windows in same webview
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
