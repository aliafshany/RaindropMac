// LoginView.swift
// Cozy mini welcome — fits the tiny companion window

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isHoveringButton = false
    @State private var animateIn = false
    @State private var ctaVisible = false
    @State private var footerVisible = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Brand gradient adapts slightly for light vs dark system preference on login
            LinearGradient(
                colors: colorScheme == .light
                    ? [
                        Color(red: 0.98, green: 0.94, blue: 0.93),
                        Color(red: 0.96, green: 0.88, blue: 0.90),
                        Color(red: 0.92, green: 0.86, blue: 0.94)
                      ]
                    : [
                        Color(red: 0.10, green: 0.07, blue: 0.10),
                        Color(red: 0.16, green: 0.09, blue: 0.12),
                        Color(red: 0.12, green: 0.08, blue: 0.14)
                      ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Static blobs only — no forever pulse animation (idle CPU)
            GeometryReader { geo in
                Circle()
                    .fill(Theme.accent.opacity(0.22))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: -40, y: geo.size.height * 0.12)

                Circle()
                    .fill(Theme.accentSecondary.opacity(0.16))
                    .frame(width: 160, height: 160)
                    .blur(radius: 50)
                    .offset(x: geo.size.width - 90, y: geo.size.height * 0.62)
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: Theme.accent.opacity(0.45), radius: 16, y: 6)

                        Image(systemName: "drop.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-15))
                    }
                    .scaleEffect(animateIn ? 1.0 : 0.94)
                    .opacity(animateIn ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("Raindrop")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.4)
                            .foregroundStyle(colorScheme == .light ? Color.primary : .white)

                        Text("A cozy place for your links")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(colorScheme == .light ? Color.secondary : .white.opacity(0.5))
                    }
                    .offset(y: animateIn ? 0 : 8)
                    .opacity(animateIn ? 1 : 0)
                }

                Spacer().frame(height: 32)

                Button {
                    authService.startOAuth()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Sign in")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 12)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(
                        color: Theme.accent.opacity(isHoveringButton ? 0.55 : 0.35),
                        radius: isHoveringButton ? 14 : 10,
                        y: 4
                    )
                    .scaleEffect(isHoveringButton ? 1.02 : 1.0)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
                .disabled(authService.clientID.isEmpty)
                .onHover { hovering in
                    withAnimation(Theme.press) { isHoveringButton = hovering }
                }
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 8)

                Spacer().frame(height: 16)

                Group {
                    if authService.clientID.isEmpty {
                        VStack(spacing: 4) {
                            Text("Add API keys in Settings")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("⌘,  ·  Client ID & Secret")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Secure OAuth · Raindrop.io")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(footerVisible ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(Theme.entrance) { animateIn = true }
            withAnimation(Theme.easeOut.delay(0.1)) { ctaVisible = true }
            withAnimation(Theme.exit.delay(0.16)) { footerVisible = true }
        }
    }
}
