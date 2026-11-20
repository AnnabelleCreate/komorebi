import SwiftUI

/// Komorebi's loading screen: sunlight moving through ginkgo leaves.
///
/// It waits a moment before appearing, so quick loads never flash a spinner.
/// If loading runs long, it says so plainly and can offer a way out.
struct LoadingView: View {
    enum Style { case fullScreen, inline }

    var message = "Settling in…"
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
            if style == .fullScreen { Palette.background.ignoresSafeArea() }
            if visible {
                VStack(spacing: 22) {
                    DappledLight(reduce: reduce)
                        .frame(width: style == .fullScreen ? 132 : 96, height: style == .fullScreen ? 132 : 96)
                    if style == .fullScreen {
                        Text("komorebi").font(KFont.title(28, relativeTo: .title)).foregroundStyle(Palette.text)
                    }
                    VStack(spacing: 8) {
                        Text(message)
                            .font(KFont.body(15))
                            .foregroundStyle(Palette.text2)
                        if slow {
                            Text(slowMessage)
                                .font(KFont.body(13))
                                .foregroundStyle(Palette.text3)
                                .transition(.opacity)
                            if let slowActionTitle, let slowAction {
                                Button(slowActionTitle, action: slowAction)
                                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                                    .padding(.top, 6)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
                .transition(.opacity)
                .accessibilityElement(children: .contain)
            }
        }
        .frame(maxWidth: style == .fullScreen ? .infinity : nil, maxHeight: style == .fullScreen ? .infinity : nil)
        .task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { visible = true }
            UIAccessibility.post(notification: .announcement, argument: message)
            try? await Task.sleep(for: .seconds(max(0, slowAfter - delay)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { slow = true }
            UIAccessibility.post(notification: .announcement, argument: slowMessage)
        }
    }
}

/// A warm sun with ginkgo leaves drifting across it and small dapples of light.
/// With Reduce Motion, nothing moves; the light only brightens and dims softly.
struct DappledLight: View {
    var reduce: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let s = min(size.width, size.height) * 0.8
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let breathe = 0.5 + 0.5 * sin(t * 2 * .pi / 4.5)

                // Glow and sun
                let glowR = s * (0.5 + 0.04 * breathe)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR * 2, height: glowR * 2)),
                         with: .radialGradient(Gradient(colors: [Palette.gold.opacity(0.38 + 0.12 * breathe), Palette.gold.opacity(0)]),
                                               center: c, startRadius: s * 0.18, endRadius: glowR))
                let sunR = s * 0.26
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - sunR, y: c.y - sunR, width: sunR * 2, height: sunR * 2)),
                         with: .color(Palette.gold))

                // Leaves passing in front of the sun
                let leaves: [(x: Double, y: Double, scale: Double, angle: Double, phase: Double)] = [
                    (-0.2, 0.12, 0.34, -0.5, 0), (0.22, 0.2, 0.26, 0.6, 2.1), (0.05, -0.24, 0.2, 0.15, 4.2),
                ]
                for leaf in leaves {
                    let sway = reduce ? 0 : sin(t * 0.7 + leaf.phase)
                    let drift = reduce ? 0 : sin(t * 0.35 + leaf.phase) * 0.06
                    let p = CGPoint(x: c.x + (leaf.x + drift) * s, y: c.y + leaf.y * s + sway * s * 0.02)
                    ctx.drawLayer { layer in
                        layer.translateBy(x: p.x, y: p.y)
                        layer.rotate(by: .radians(leaf.angle + sway * 0.12))
                        layer.fill(Self.ginkgo(radius: s * leaf.scale), with: .color(Palette.cardRaised.opacity(0.92)))
                    }
                }

                // Dapples of light
                let dapples: [(x: Double, y: Double, r: Double, phase: Double)] = [
                    (-0.36, 0.34, 0.035, 0), (0.33, -0.3, 0.028, 1.7), (0.4, 0.3, 0.022, 3.1), (-0.3, -0.36, 0.02, 4.6),
                ]
                for d in dapples {
                    let a = 0.25 + 0.6 * (0.5 + 0.5 * sin(t * 1.1 + d.phase))
                    let r = s * d.r
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x + d.x * s - r, y: c.y + d.y * s - r, width: r * 2, height: r * 2)),
                             with: .color(Palette.text.opacity(a)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// A ginkgo leaf: a fan with a notch at the top and a short stem.
    static func ginkgo(radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.12), endAngle: .radians(.pi * 1.47), clockwise: false)
        p.addLine(to: CGPoint(x: 0, y: -r * 0.62))
        p.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.53), endAngle: .radians(.pi * 1.88), clockwise: false)
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: -r * 0.03, y: 0, width: r * 0.06, height: r * 0.7), cornerSize: CGSize(width: r * 0.03, height: r * 0.03))
        return p
    }
}

#Preview("Loading") {
    LoadingView(message: "Settling in…", delay: 0, slowAfter: 3, slowActionTitle: "Try again", slowAction: {})
}
