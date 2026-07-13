// ReaderView.swift
// In-app permanent copy / link reader (WKWebView)

import SwiftUI
import WebKit

struct ReaderView: View {
    let raindrop: Raindrop
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var useCache = true
    @State private var isLoading = true

    private func close() {
        viewModel.readerRaindrop = nil
        dismiss()
    }

    private var cacheURL: URL? {
        URL(string: "https://api.raindrop.io/rest/v1/raindrop/\(raindrop.id)/cache")
    }

    private var pageURL: URL? {
        if useCache, raindrop.cache?.status == "ready", let cacheURL {
            return cacheURL
        }
        return URL(string: raindrop.link)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(raindrop.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(raindrop.displayDomain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if raindrop.cache?.status == "ready" {
                    Picker("", selection: $useCache) {
                        Text("Archive").tag(true)
                        Text("Live").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .controlSize(.small)
                }

                Button {
                    if let url = URL(string: raindrop.link) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open in browser")

                ModalCloseButton { close() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ZStack {
                if let url = pageURL {
                    ReaderWebView(url: url, isLoading: $isLoading)
                        .id("\(url.absoluteString)-\(useCache)")
                } else {
                    Text("No URL available")
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView("Loading…")
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }
}

struct ReaderWebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        // Auth for cache endpoint if needed — load plain URL; public cache may redirect
        var request = URLRequest(url: url)
        if let token = AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        web.load(request)
        return web
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>
        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}
