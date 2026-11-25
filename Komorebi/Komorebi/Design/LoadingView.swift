import Observation
import SwiftUI

// MARK: - Splash

/// The Figma "App / Splash" screen, shown when Komorebi opens. It fades out after about 1.2 seconds.
struct SplashView: View {
    var body: some View {
        GeometryReader { geo in
            Image("splash")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .background(Palette.background.ignoresSafeArea())
        .accessibilityElement()
        .accessibilityLabel("Komorebi")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Loading overlay

/// Komorebi's loading screen: a dark indigo layer over the whole screen, with a golden ginkgo leaf
/// circling slowly at a steady pace, like a loading ring.
///
/// - It waits a moment before appearing, so quick actions never flash it.
/// - If loading runs long, it says so plainly and can offer a way out.
/// - Motion is slow, linear and never flashes (WCAG 2.3.1). With Reduce Motion the leaf stays still
///   and only its glow breathes gently. Text on the layer is well above 4.5:1 contrast (WCAG 1.4.3).
/// - VoiceOver announces it and keeps focus on it while it's showing (WCAG 4.1.3).
struct LoadingView: View {
    enum Style { case fullScreen, inline }

    var message = "Just a moment…"
    var style: Style = .fullScreen
    /// How long to wait before showing anything.
    var delay: Double = 0.4
    /// When to admit it's slow.
    var slowAfter: Double = 8
    var slowMessage = "This is taking a little longer than usual."
    var slowActionTitle: String?
    var slowAction: (() -> Void)?

    @Environment(\.komorebiReduceMotion) private var reduce
    @State private var visible = false
    @State private var slow = false

    var body: some View {
        ZStack {
            if visible {
                if style == .fullScreen {
                    // Dark indigo from the design system, so the screen underneath is dimmed, not hidden.
                    Palette.background.opacity(0.9).ignoresSafeArea().transition(.opacity)
                }
                VStack(spacing: 24) {
                    LeafOrbit(reduce: reduce)
                        .frame(width: 96, height: 96)
                    VStack(spacing: 8) {
                        Text(message)
                            .font(KFont.body(16))
                            .foregroundStyle(Palette.text)
                        if slow {
                            Text(slowMessage)
                                .font(KFont.body(14))
                                .foregroundStyle(Palette.text2)
                                .transition(.opacity)
                            if let slowActionTitle, let slowAction {
                                Button(slowActionTitle, action: slowAction)
                                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                                    .padding(.top, 8)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
                .transition(.opacity)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Loading. \(message)")
            }
        }
        .frame(maxWidth: style == .fullScreen ? .infinity : nil, maxHeight: style == .fullScreen ? .infinity : nil)
        .contentShape(Rectangle())
        .allowsHitTesting(visible && style == .fullScreen)
        .accessibilityAddTraits(visible && style == .fullScreen ? .isModal : [])
        .task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { visible = true }
            UIAccessibility.post(notification: .announcement, argument: message)
            try? await Task.sleep(for: .seconds(max(0, slowAfter - delay)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { slow = true }
            UIAccessibility.post(notification: .announcement, argument: slowMessage)
        }
    }
}

/// A golden ginkgo leaf travelling around a faint ring at one steady speed (one lap every 3.2 seconds).
struct LeafOrbit: View {
    var reduce: Bool
    private let lap: Double = 3.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                // Sized so the leaf, its glow and trail always stay inside the frame.
                let ringRadius = min(size.width, size.height) * 0.3
                let leafSize = min(size.width, size.height) * 0.17

                // The ring the leaf follows.
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringRadius, y: c.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)),
                           with: .color(Palette.outlineStrong.opacity(0.45)), lineWidth: 1.5)

                // Linear, constant motion: no easing, no speed changes.
                let angle = reduce ? -Double.pi / 2 : (t.truncatingRemainder(dividingBy: lap) / lap) * 2 * .pi - .pi / 2
                let p = CGPoint(x: c.x + cos(angle) * ringRadius, y: c.y + sin(angle) * ringRadius)

                // A short fading trail behind the leaf shows which way it's going.
                if !reduce {
                    for i in 1...10 {
                        let a = angle - Double(i) * 0.09
                        let q = CGPoint(x: c.x + cos(a) * ringRadius, y: c.y + sin(a) * ringRadius)
                        let r = 2.6 - Double(i) * 0.18
                        ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Palette.gold.opacity(0.42 - Double(i) * 0.04)))
                    }
                }

                let breathe = reduce ? 0.75 + 0.25 * sin(t * 2 * .pi / 3) : 1
                let glow = leafSize * 1.2
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)),
                         with: .radialGradient(Gradient(colors: [Palette.gold.opacity(0.3 * breathe), Palette.gold.opacity(0)]),
                                               center: p, startRadius: 0, endRadius: glow))
                ctx.drawLayer { layer in
                    layer.translateBy(x: p.x, y: p.y)
                    // The leaf's tip leads along the ring, stem trailing; it sits centred on the ring.
                    layer.rotate(by: .radians(angle + .pi))
                    layer.translateBy(x: 0, y: leafSize * 0.2)
                    layer.fill(GinkgoLeaf.path(radius: leafSize), with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFE3A6), Palette.gold, Color(hex: 0xE2B262)]),
                        startPoint: CGPoint(x: 0, y: -leafSize), endPoint: CGPoint(x: 0, y: leafSize * 0.2)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

enum GinkgoLeaf {
    /// A ginkgo leaf: a fan with a notch at the top and a short stem, centred on the stem base.
    static func path(radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.12), endAngle: .radians(.pi * 1.47), clockwise: false)
        p.addLine(to: CGPoint(x: 0, y: -r * 0.62))
        p.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.53), endAngle: .radians(.pi * 1.88), clockwise: false)
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: -r * 0.04, y: 0, width: r * 0.08, height: r * 0.6), cornerSize: CGSize(width: r * 0.04, height: r * 0.04))
        return p
    }
}

// MARK: - App-wide loading

/// Tracks anything that's taking a while, so one full-screen loading layer can cover it.
@Observable
final class LoadingCenter {
    static let shared = LoadingCenter()
    private(set) var tasks: [String: String] = [:]
    private(set) var recoveringFromFreeze = false

    private init() {}

    var isActive: Bool { !tasks.isEmpty || recoveringFromFreeze }
    var message: String { tasks.values.sorted().first ?? "Just a moment…" }

    func begin(_ id: String, _ message: String) { tasks[id] = message }
    func end(_ id: String) { tasks[id] = nil }

    /// Called after the app was frozen for a while: shows the loading layer briefly while things catch up.
    func reportFreeze() {
        recoveringFromFreeze = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.recoveringFromFreeze = false }
    }
}

/// Watches for the app freezing. iOS can't draw anything while the app is frozen, so the moment it's able to again,
/// the loading layer covers the screen while things catch up, instead of showing a half-updated screen.
final class FreezeWatchdog {
    static let shared = FreezeWatchdog()
    private var started = false
    private init() {}

    func start() {
        guard !started else { return }
        started = true
        let thread = Thread {
            while true {
                let answered = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { answered.signal() }
                if answered.wait(timeout: .now() + 1.0) == .timedOut {
                    // Frozen for more than a second. Wait for it to recover, then cover the screen while it catches up.
                    answered.wait()
                    DispatchQueue.main.async { LoadingCenter.shared.reportFreeze() }
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        thread.name = "Komorebi freeze watchdog"
        thread.qualityOfService = .utility
        thread.start()
    }
}

/// Puts the app-wide loading layer on top of a screen.
struct LoadingHost: ViewModifier {
    @State private var center = LoadingCenter.shared
    func body(content: Content) -> some View {
        content.overlay {
            if center.isActive {
                LoadingView(message: center.message, delay: center.recoveringFromFreeze ? 0 : 0.4)
                    .id(center.message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: center.isActive)
    }
}

extension View {
    func loadingHost() -> some View { modifier(LoadingHost()) }
}

#Preview("Loading") {
    ZStack {
        Color(hex: 0x2B2F4D).ignoresSafeArea()
        LoadingView(message: "Just a moment…", delay: 0, slowAfter: 3, slowActionTitle: "Try again", slowAction: {})
    }
}
