// Theme.swift
// Design tokens + motion craft + efficient hover tooltips

import SwiftUI
import AppKit

enum Theme {
    // Warm coral — works on light & dark (slightly brighter secondary for dark UIs)
    static let accent = Color(red: 0.93, green: 0.42, blue: 0.36)
    static let accentSecondary = Color(red: 0.82, green: 0.40, blue: 0.58)
    static let success = Color(red: 0.28, green: 0.72, blue: 0.48)
    static let warning = Color(red: 0.95, green: 0.66, blue: 0.28)
    static let danger = Color(red: 0.90, green: 0.32, blue: 0.34)

    // Dense cozy geometry
    static let cardRadius: CGFloat = 12
    static let chipRadius: CGFloat = 7
    static let controlRadius: CGFloat = 9

    // Companion window with collapsible sidebar
    static let windowWidth: CGFloat = 780
    static let windowHeight: CGFloat = 720
    static let windowMinWidth: CGFloat = 560
    static let windowMinHeight: CGFloat = 520
    static let sidebarIdeal: CGFloat = 220
    static let sidebarMin: CGFloat = 180
    static let sidebarMax: CGFloat = 300
    static let sheetWidth: CGFloat = 400
    static let sheetHeight: CGFloat = 540
    static let thumbSize: CGFloat = 52

    // Adaptive surfaces (resolve against current appearance)
    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var controlFill: Color { Color(nsColor: .controlBackgroundColor) }
    static var textPrimary: Color { Color(nsColor: .labelColor) }
    static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
    static var separator: Color { Color(nsColor: .separatorColor) }

    /// Search field / chips fill that works in light & dark
    static var searchFieldFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.05)
        })
    }

    static var cardStroke: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor.white.withAlphaComponent(0.10)
                : NSColor.black.withAlphaComponent(0.08)
        })
    }

    // MARK: - Motion tokens
    // Critically damped defaults (no bounce) for UI chrome.
    // Slight bounce only for rare delight (login icon, success).

    /// Button press / hover micro-feedback — ~100–160ms feel
    static var press: Animation {
        .spring(response: 0.18, dampingFraction: 1.0)
    }

    /// Snappy UI: chips, selection, small popovers — ~150–200ms
    static var snappy: Animation {
        .spring(response: 0.28, dampingFraction: 0.92)
    }

    /// Standard panel / card / list transitions — ~200–250ms ease-out feel
    static var easeOut: Animation {
        .spring(response: 0.36, dampingFraction: 0.95)
    }

    /// On-screen morphs (expand/collapse) — ease-in-out character
    static var morph: Animation {
        .spring(response: 0.4, dampingFraction: 1.0)
    }

    /// Occasional entrance (login, empty state) — soft settle, minimal bounce
    static var entrance: Animation {
        .spring(response: 0.5, dampingFraction: 0.86)
    }

    /// Fast exit (asymmetric: exit faster than enter)
    static var exit: Animation {
        .spring(response: 0.22, dampingFraction: 1.0)
    }

    static let pressScale: CGFloat = 0.97
    static let enterScale: CGFloat = 0.96  // never animate from 0

    static var sidebarBackground: Color { windowBackground }

    static var cardBackground: Color { controlFill }

    static var elevatedBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }

    static var hairline: Color { cardStroke }

    static var subtleFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.04)
        })
    }

    static func color(fromHex hex: String?) -> Color? {
        guard var h = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return nil }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    static func formatDate(_ dateString: String?) -> String {
        guard let dateString else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: dateString)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: dateString)
        }
        guard let date else { return dateString }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }

    static func relativeDate(_ dateString: String?) -> String {
        guard let dateString else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: dateString)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: dateString)
        }
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Pressable button style (scale 0.97 on press — Emil + Apple)

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = Theme.pressScale
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

/// Soft hover lift for cards / primary CTAs (macOS pointer)
struct HoverLiftModifier: ViewModifier {
    @State private var isHovering = false
    var hoverScale: CGFloat = 1.015
    var enabled: Bool = true

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && isHovering ? hoverScale : 1)
            .animation(Theme.press, value: isHovering)
            .onHover { hovering in
                guard enabled else { return }
                isHovering = hovering
            }
    }
}

// MARK: - Click-outside dismissible modal

/// Visible close control (readable in light & dark).
struct ModalCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 26, height: 26)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .tooltip("Close")
        .accessibilityLabel("Close")
    }
}

struct ScrimModal<Content: View>: View {
    @Binding var isPresented: Bool
    var width: CGFloat = 440
    var height: CGFloat = 480
    @ViewBuilder var content: () -> Content

    @State private var mouseMonitor: Any?

    var body: some View {
        ZStack {
            // Covers content area
            Color.black.opacity(0.36)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture { dismissModal() }

            content()
                .frame(width: width, height: height)
                .background(Theme.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 28, y: 12)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .onAppear { installOutsideClickMonitor() }
        .onDisappear { removeOutsideClickMonitor() }
        .background {
            Button("") { dismissModal() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private func dismissModal() {
        withAnimation(.easeOut(duration: 0.15)) {
            isPresented = false
        }
    }

    /// Catches clicks on the title bar / toolbar too (SwiftUI scrim often stops below it).
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [width, height] event in
            guard let window = event.window ?? NSApp.keyWindow else { return event }
            let loc = event.locationInWindow
            let bounds = window.contentLayoutRect
            // Panel is centered in the content layout rect
            let panelRect = CGRect(
                x: bounds.midX - width / 2,
                y: bounds.midY - height / 2,
                width: width,
                height: height
            )
            if !panelRect.contains(loc) {
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPresented = false
                    }
                }
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }
}

extension View {
    /// Present a panel that closes when the user clicks outside it (including toolbar).
    func scrimModal<Content: View>(
        isPresented: Binding<Bool>,
        width: CGFloat = 440,
        height: CGFloat = 480,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                ScrimModal(isPresented: isPresented, width: width, height: height, content: content)
                    .zIndex(999)
            }
        }
    }

    func hoverLift(_ enabled: Bool = true, scale: CGFloat = 1.015) -> some View {
        modifier(HoverLiftModifier(hoverScale: scale, enabled: enabled))
    }

    /// Soft cozy shadow — no per-elevation animation (cheaper while scrolling)
    func cardShadow(elevated: Bool) -> some View {
        shadow(
            color: .black.opacity(elevated ? 0.1 : 0.04),
            radius: elevated ? 8 : 3,
            y: elevated ? 3 : 1
        )
    }

    /// Hover tooltip: delayed (~0.75s), stable bubble, no shake.
    func tooltip(_ text: String) -> some View {
        modifier(HoverTooltipModifier(text: text))
    }
}

// MARK: - Hover tooltips

/// Tooltip only after resting the pointer — never on click / menu open.
struct HoverTooltipModifier: ViewModifier {
    let text: String
    /// Rest on the control this long before the bubble appears
    var delayMs: UInt64 = 800

    @State private var isHovering = false
    @State private var showTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .accessibilityHint(text)
            .onHover { hovering in
                isHovering = hovering
                showTask?.cancel()
                if hovering {
                    // Schedule show only after a still hover (not a click)
                    showTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                        guard !Task.isCancelled, isHovering, !text.isEmpty else { return }
                        // Don't show if a mouse button is held (menu about to open / drag)
                        guard NSEvent.pressedMouseButtons == 0 else { return }
                        FloatingTooltip.shared.show(text)
                    }
                } else {
                    showTask = nil
                    FloatingTooltip.shared.hide()
                }
            }
            // Any press cancels pending tooltip and hides an open one
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        showTask?.cancel()
                        showTask = nil
                        FloatingTooltip.shared.hide()
                    }
            )
            .onDisappear {
                showTask?.cancel()
                FloatingTooltip.shared.hide()
            }
    }
}

/// Floating NSPanel — hover-only; hidden immediately on any click.
@MainActor
enum FloatingTooltip {
    static let shared = Presenter()

    final class Presenter {
        private var panel: NSPanel?
        private var label: NSTextField?
        private var currentText: String?
        private var clickMonitor: Any?
        private var keyMonitor: Any?

        func show(_ text: String) {
            if currentText == text, panel?.isVisible == true { return }
            // Never show while clicking
            guard NSEvent.pressedMouseButtons == 0 else { return }

            currentText = text
            ensureClickHidesMonitor()

            let appearance = NSApp.effectiveAppearance
            let padX: CGFloat = 10
            let padY: CGFloat = 7

            let field: NSTextField
            if let existing = label {
                field = existing
                field.stringValue = text
            } else {
                field = NSTextField(labelWithString: text)
                field.font = .systemFont(ofSize: 11, weight: .medium)
                field.backgroundColor = .clear
                field.isBezeled = false
                field.drawsBackground = false
                field.lineBreakMode = .byWordWrapping
                field.maximumNumberOfLines = 3
                label = field
            }
            field.appearance = appearance
            field.textColor = .labelColor
            field.preferredMaxLayoutWidth = 260
            field.sizeToFit()

            let size = NSSize(
                width: ceil(field.fittingSize.width) + padX * 2,
                height: ceil(field.fittingSize.height) + padY * 2
            )
            field.frame = NSRect(
                x: padX, y: padY,
                width: size.width - padX * 2,
                height: size.height - padY * 2
            )

            let mouse = NSEvent.mouseLocation
            let origin = NSPoint(
                x: round(mouse.x - size.width / 2),
                y: round(mouse.y - size.height - 16)
            )
            let frame = NSRect(origin: origin, size: size)

            if let panel {
                panel.appearance = appearance
                panel.setFrame(frame, display: true)
                if panel.contentView !== field.superview {
                    panel.contentView = makeContainer(size: size, label: field)
                } else if let container = panel.contentView {
                    container.frame = NSRect(origin: .zero, size: size)
                    field.frame = NSRect(
                        x: padX, y: padY,
                        width: size.width - padX * 2,
                        height: size.height - padY * 2
                    )
                }
                if !panel.isVisible { panel.orderFront(nil) }
            } else {
                let container = makeContainer(size: size, label: field)
                let panel = NSPanel(
                    contentRect: frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = true
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.hidesOnDeactivate = true
                panel.ignoresMouseEvents = true
                panel.animationBehavior = .none
                panel.appearance = appearance
                panel.contentView = container
                panel.orderFront(nil)
                self.panel = panel
            }
        }

        func hide() {
            currentText = nil
            panel?.orderOut(nil)
        }

        /// Any mouse down or key press dismisses the bubble (menus, clicks, etc.)
        private func ensureClickHidesMonitor() {
            if clickMonitor == nil {
                clickMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
                ) { event in
                    FloatingTooltip.shared.hide()
                    return event
                }
            }
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    FloatingTooltip.shared.hide()
                    return event
                }
            }
        }

        private func makeContainer(size: NSSize, label: NSTextField) -> NSView {
            let appearance = NSApp.effectiveAppearance
            let container = NSView(frame: NSRect(origin: .zero, size: size))
            container.wantsLayer = true
            container.appearance = appearance
            var bg = NSColor.controlBackgroundColor
            var border = NSColor.separatorColor
            appearance.performAsCurrentDrawingAppearance {
                bg = NSColor.controlBackgroundColor
                border = NSColor.separatorColor
            }
            container.layer?.backgroundColor = bg.cgColor
            container.layer?.cornerRadius = 7
            container.layer?.borderWidth = 1
            container.layer?.borderColor = border.cgColor
            container.layer?.masksToBounds = true
            label.removeFromSuperview()
            container.addSubview(label)
            return container
        }
    }
}

// MARK: - Reusable UI pieces

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

struct ModernChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.accent
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? color : color.opacity(0.12))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .disabled(action == nil)
    }
}

struct SectionLabel: View {
    let title: String
    var icon: String? = nil
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
        }
        .foregroundStyle(color)
        .tracking(0.4)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.16), Theme.accentSecondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accent.opacity(0.75))
                    .symbolRenderingMode(.hierarchical)
            }
            .scaleEffect(appeared ? 1 : Theme.enterScale)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
            .offset(y: appeared ? 0 : 6)
            .opacity(appeared ? 1 : 0)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(Theme.entrance.delay(0.04)) {
                appeared = true
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// Masonry grid helper
struct MasonryLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        let colWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let i = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            heights[i] += size.height + spacing
        }

        return CGSize(width: width, height: max(0, (heights.max() ?? 0) - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let colWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let i = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            let x = bounds.minX + CGFloat(i) * (colWidth + spacing)
            let y = bounds.minY + heights[i]
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: colWidth, height: size.height)
            )
            heights[i] += size.height + spacing
        }
    }
}
