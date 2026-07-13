// LoginView.swift
// Modern login screen with Raindrop.io OAuth

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isHoveringButton = false
    @State private var animateIn = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Layered gradient
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.12),
                    Color(red: 0.06, green: 0.10, blue: 0.24),
                    Color(red: 0.04, green: 0.14, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient orbs
            GeometryReader { geo in
                Circle()
                    .fill(Theme.accent.opacity(0.22))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .offset(x: -100, y: geo.size.height * 0.05)
                    .scaleEffect(pulse ? 1.08 : 0.95)

                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: geo.size.width - 160, y: geo.size.height * 0.55)
                    .scaleEffect(pulse ? 0.95 : 1.08)

                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.75)
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(color: Theme.accent.opacity(0.55), radius: 28, y: 8)

                        Image(systemName: "drop.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-15))
                    }
                    .scaleEffect(animateIn ? 1.0 : 0.55)
                    .opacity(animateIn ? 1 : 0)

                    VStack(spacing: 10) {
                        Text("Raindrop")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.82)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("Native bookmark manager for macOS")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .offset(y: animateIn ? 0 : 18)
                    .opacity(animateIn ? 1 : 0)
                }

                // Feature pills
                HStack(spacing: 10) {
                    featurePill("Collections", icon: "folder.fill")
                    featurePill("Tags", icon: "tag.fill")
                    featurePill("Full search", icon: "magnifyingglass")
                }
                .padding(.top, 28)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)

                Spacer().frame(height: 48)

                Button {
                    authService.startOAuth()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sign in with Raindrop.io")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 15)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [Theme.accent, Theme.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            if isHoveringButton {
                                Color.white.opacity(0.1)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Theme.accent.opacity(isHoveringButton ? 0.65 : 0.4), radius: isHoveringButton ? 22 : 14, y: 6)
                    .scaleEffect(isHoveringButton ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(authService.clientID.isEmpty)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        isHoveringButton = hovering
                    }
                }
                .offset(y: animateIn ? 0 : 24)
                .opacity(animateIn ? 1 : 0)

                Spacer().frame(height: 24)

                Group {
                    if authService.clientID.isEmpty {
                        VStack(spacing: 6) {
                            Label("API credentials required", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("Press ⌘, to open Settings and paste your Client ID & Secret.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    } else {
                        Text("Secure OAuth · Your data stays on Raindrop.io")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .opacity(animateIn ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, 48)
        }
        .frame(minWidth: 520, minHeight: 460)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.08)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func featurePill(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }
}
