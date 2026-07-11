// LoginView.swift
// Beautiful login screen with Raindrop.io OAuth

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isHoveringButton = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.12, blue: 0.28),
                    Color(red: 0.03, green: 0.18, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: -80, y: geo.size.height * 0.1)

                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: geo.size.width - 150, y: geo.size.height * 0.5)
            }

            VStack(spacing: 0) {
                Spacer()

                // Logo + Title
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.0, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: .blue.opacity(0.5), radius: 20)

                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(animateIn ? 1.0 : 0.6)
                    .opacity(animateIn ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("Raindrop")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(white: 0.8)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                        Text("Your bookmarks, beautifully organized.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .offset(y: animateIn ? 0 : 20)
                    .opacity(animateIn ? 1 : 0)
                }

                Spacer().frame(height: 52)

                // Login button
                Button {
                    authService.startOAuth()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Sign in with Raindrop.io")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.49, blue: 0.98), Color(red: 0.2, green: 0.3, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            if isHoveringButton {
                                Color.white.opacity(0.08)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .blue.opacity(isHoveringButton ? 0.7 : 0.4), radius: isHoveringButton ? 20 : 12)
                    .scaleEffect(isHoveringButton ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(authService.clientID.isEmpty)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHoveringButton = hovering
                    }
                }
                .offset(y: animateIn ? 0 : 30)
                .opacity(animateIn ? 1 : 0)

                Spacer().frame(height: 28)

                if authService.clientID.isEmpty {
                    VStack(spacing: 4) {
                        Text("API Credentials missing.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("Press ⌘, (Command + Comma) to open Settings and configure.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .opacity(animateIn ? 1 : 0)
                } else {
                    Text("You'll be redirected to Raindrop.io to sign in securely.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .opacity(animateIn ? 1 : 0)
                }

                Spacer()
            }
            .padding(.horizontal, 60)
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                animateIn = true
            }
        }
    }
}
