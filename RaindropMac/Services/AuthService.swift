// AuthService.swift
// Handles OAuth 2.0 authentication with Raindrop.io

import Foundation
import AppKit
import Network

class AuthService: ObservableObject {
    static let shared = AuthService()

    // MARK: - Configuration
    var clientID: String {
        UserDefaults.standard.string(forKey: "client_id") ?? ""
    }
    
    var clientSecret: String {
        UserDefaults.standard.string(forKey: "client_secret") ?? ""
    }
    
    static let redirectURI  = "http://localhost:54321/auth/callback"
    static let authURL      = "https://raindrop.io/oauth/authorize"
    static let tokenURL     = "https://raindrop.io/oauth/access_token"

    private let keychainKey = "raindrop_access_token"
    private let refreshKey  = "raindrop_refresh_token"
    
    private var localServer: NWListener?

    @Published var accessToken: String? {
        didSet { saveToken() }
    }
    @Published var isAuthenticated = false

    private init() {
        loadToken()
    }

    // MARK: - Token Persistence
    private func saveToken() {
        guard let token = accessToken else {
            UserDefaults.standard.removeObject(forKey: keychainKey)
            return
        }
        UserDefaults.standard.set(token, forKey: keychainKey)
        isAuthenticated = true
    }

    private func loadToken() {
        if let token = UserDefaults.standard.string(forKey: keychainKey), !token.isEmpty {
            self.accessToken = token
            self.isAuthenticated = true
        }
    }

    func saveRefreshToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: refreshKey)
    }

    // MARK: - OAuth Flow
    func startOAuth() {
        // Start local HTTP server to receive the callback
        startLocalServer()
        
        var components = URLComponents(string: AuthService.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: self.clientID),
            URLQueryItem(name: "redirect_uri", value: AuthService.redirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Local HTTP Server for OAuth Callback
    private func startLocalServer() {
        stopLocalServer()
        
        do {
            let params = NWParameters.tcp
            let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: 54321))
            
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("Local server failed: \(error)")
                }
            }
            
            listener.start(queue: .main)
            self.localServer = listener
        } catch {
            print("Failed to start local server: \(error)")
        }
    }
    
    private func stopLocalServer() {
        localServer?.cancel()
        localServer = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            // Parse the HTTP request line to extract the path and query
            if let firstLine = requestString.components(separatedBy: "\r\n").first,
               let urlPart = firstLine.split(separator: " ").dropFirst().first,
               let url = URL(string: "http://localhost:54321\(urlPart)"),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                
                // Send a nice HTML response to the browser
                let htmlResponse = """
                <!DOCTYPE html>
                <html>
                <head><meta charset="UTF-8"><title>RaindropMac</title></head>
                <body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:linear-gradient(135deg,#0d0d1f,#142040,#0a3060);color:white;">
                <div style="text-align:center;">
                <h1 style="font-size:2.5em;">&#10004; Authenticated!</h1>
                <p style="opacity:0.6;font-size:1.1em;">You can close this tab and return to RaindropMac.</p>
                </div>
                </body>
                </html>
                """
                let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(htmlResponse.utf8.count)\r\nConnection: close\r\n\r\n\(htmlResponse)"
                
                connection.send(content: httpResponse.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                
                // Exchange the code for a token
                self.exchangeCodeForToken(code: code)
                
                // Stop the server
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.stopLocalServer()
                }
            } else {
                // Not the callback we're looking for
                let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    func handleRedirect(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: AuthService.tokenURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "code": code,
            "client_id": self.clientID,
            "client_secret": self.clientSecret,
            "redirect_uri": AuthService.redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                print("Token exchange network error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.accessToken = response.accessToken
                    if let refresh = response.refreshToken {
                        self?.saveRefreshToken(refresh)
                    }
                    self?.isAuthenticated = true
                }
            } catch {
                print("Token decode error: \(error)")
                // Try to parse as a generic dictionary as fallback
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["access_token"] as? String {
                    DispatchQueue.main.async {
                        self?.accessToken = token
                        if let refresh = json["refresh_token"] as? String {
                            self?.saveRefreshToken(refresh)
                        }
                        self?.isAuthenticated = true
                    }
                }
            }
        }.resume()
    }

    func signOut() {
        accessToken = nil
        UserDefaults.standard.removeObject(forKey: keychainKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        isAuthenticated = false
    }

    /// Wipe OAuth app credentials + tokens from this Mac (never ship secrets in the repo).
    func clearAllCredentials() {
        signOut()
        UserDefaults.standard.removeObject(forKey: "client_id")
        UserDefaults.standard.removeObject(forKey: "client_secret")
        // Force AppStorage / Settings fields to refresh if already open
        UserDefaults.standard.synchronize()
    }
}
