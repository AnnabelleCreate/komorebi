import SwiftUI

/// Lantern release · inspired by tōrō nagashi.
/// Write one thought, fold it into a paper lantern, breathe out to send it down the river.
/// The words are never saved: they live only in this view and are cleared when the lantern drifts away.
struct LanternView: View {
    enum Step { case begin, write, folding, release, drifting, rest }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var step: Step = .begin
    @State private var thought = ""
    @State private var breath = BreathDetector()
    @State private var holdProgress: Double = 0
    @State private var holding = false
    @State private var driftStart: Date?
    @State private var foldAmount: Double = 0
    @FocusState private var writing: Bool

    private let limit = 160

    var body: some View {
        ZStack {
            LanternScene(driftStart: driftStart, reduce: reduce, showLantern: step != .begin && step != .write, glow: glow)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar
                Group {
                    switch step {
                    case .begin: beginStep
                    case .write: writeStep
                    case .folding: foldingStep
                    case .release: releaseStep
                    case .drifting: driftingStep
                    case .rest: restStep
                    }
                }
                .transition(Motion.screen(reduce))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden(true)
        .onAppear { if store.state.settings.ambience { SoundEngine.shared.setLoop(.river, level: 0.35, fade: 2) } }
        .onDisappear {
            breath.stop()
            thought = ""
            SoundEngine.shared.stopLoop(.river, fade: 1.2)
        }
    }

    private var glow: Double {
        switch step {
        case .release: return 0.35 + 0.65 * max(breath.progress, holdProgress)
        case .drifting, .rest: return 1
        default: return 0.35
        }
    }

    private func go(_ next: Step) {
        withAnimation(Motion.ease(reduce, duration: 0.6)) { step = next }
    }

    private var topBar: some View {
        HStack {
            Button {
                switch step {
                case .write: go(.begin)
                default: dismiss()
                }
            } label: {
                Image(systemName: step == .write ? "chevron.left" : "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(hex: 0x1C2139, opacity: 0.6)))
            }
            .accessibilityLabel(step == .write ? "Back" : "Close")
            Spacer()
            Text("Lantern release").font(KFont.heading(17)).foregroundStyle(Palette.text)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: Steps

    private var beginStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Eyebrow(text: "Tōrō nagashi · floating lanterns")
            Text("A little less to carry.").font(KFont.title(32)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            Text("Write one thought you’d like to set down tonight. Fold it into a paper lantern and let the river take it. Your words are never saved.")
                .font(KFont.body(16)).foregroundStyle(Palette.text2)
            Button("Begin") { go(.write); SoundEngine.shared.play(.tap, volume: 0.6) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
            Text("About 2 minutes").font(KFont.body(13)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private var writeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would you like to set down?").font(KFont.title(26)).foregroundStyle(Palette.text).padding(.top, 20)
            ZStack(alignment: .topLeading) {
                if thought.isEmpty {
                    Text("A worry, a thank-you, something unfinished…")
                        .font(KFont.reading(19, serif: true))
                        .foregroundStyle(Color(hex: 0x6B5E4A))
                        .padding(.horizontal, 18).padding(.vertical, 20)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $thought)
                    .font(KFont.reading(19, serif: true))
                    .foregroundStyle(Color(hex: 0x2B2418))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused($writing)
                    .accessibilityLabel("Your thought")
                    .onChange(of: thought) { _, value in
                        if value.count > limit { thought = String(value.prefix(limit)) }
                    }
            }
            .frame(height: 200)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xF4E8D0)))
            .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
            HStack {
                Text("Not saved anywhere").font(KFont.body(13)).foregroundStyle(Palette.text3)
                Spacer()
                Text("\(thought.count)/\(limit)").font(KFont.body(13)).foregroundStyle(Palette.text3)
                    .accessibilityLabel("\(limit - thought.count) characters left")
            }
            Spacer()
            Button("Fold it into the lantern") { fold() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Release without words") { fold() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onAppear { writing = true }
    }

    private var foldingStep: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: 0xF4E8D0))
                .frame(width: 260 * (1 - foldAmount * 0.8), height: 180 * (1 - foldAmount * 0.75))
                .rotation3DEffect(.degrees(reduce ? 0 : foldAmount * 70), axis: (x: 1, y: 0, z: 0))
                .opacity(1 - foldAmount * 0.9)
            Text("Folding…").font(KFont.body(15)).foregroundStyle(Palette.text2).padding(.top, 20)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var releaseStep: some View {
        VStack(spacing: 14) {
            Text("Blow softly. Let it go.").font(KFont.title(28)).foregroundStyle(Palette.text).padding(.top, 24)
            Text(releaseInstruction).font(KFont.body(15)).foregroundStyle(Palette.text2).multilineTextAlignment(.center).padding(.horizontal, 30)
            Spacer()
            releaseControl
            Spacer().frame(height: 40)
            if !store.state.settings.tapInsteadOfHold {
                Button("Tap to release instead") { release() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 20)
            }
            Spacer().frame(height: 20)
        }
        .onAppear(perform: startListening)
        .onDisappear { breath.stop() }
    }

    private var releaseInstruction: String {
        if store.state.settings.tapInsteadOfHold { return "Breathe out slowly, then tap the lantern." }
        switch breath.status {
        case .listening: return "Breathe out slowly toward the bottom of your phone, or press and hold the lantern."
        case .denied: return "Press and hold the lantern while you breathe out. (Microphone access is off, which is fine.)"
        case .unavailable: return "Press and hold the lantern while you breathe out."
        default: return "Press and hold the lantern, and breathe out slowly."
        }
    }

    @ViewBuilder
    private var releaseControl: some View {
        let progress = max(breath.progress, holdProgress)
        ZStack {
            Circle().stroke(Palette.gold.opacity(0.25), lineWidth: 4)
            Circle().trim(from: 0, to: progress).stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(store.state.settings.tapInsteadOfHold ? "Tap to\nlet go" : "Hold &\nbreathe out")
                .font(KFont.medium(15)).multilineTextAlignment(.center).foregroundStyle(Palette.text)
        }
        .frame(width: 128, height: 128)
        .scaleEffect(holding && !reduce ? 0.96 : 1)
        .contentShape(Circle())
        .onTapGesture { if store.state.settings.tapInsteadOfHold { release() } }
        .onLongPressGesture(minimumDuration: 2.4, maximumDistance: 40, perform: {
            if !store.state.settings.tapInsteadOfHold { release() }
        }, onPressingChanged: { pressing in
            guard !store.state.settings.tapInsteadOfHold else { return }
            holding = pressing
            if pressing {
                SoundEngine.shared.setLoop(.wind, level: 0.35, fade: 0.4)
                withAnimation(.linear(duration: 2.4)) { holdProgress = 1 }
            } else if step == .release {
                SoundEngine.shared.setLoop(.wind, level: 0, fade: 0.4)
                withAnimation(.easeOut(duration: 0.5)) { holdProgress = 0 }
            }
        })
        .accessibilityElement()
        .accessibilityLabel(store.state.settings.tapInsteadOfHold ? "Release the lantern" : "Lantern. Press and hold to release.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { release() }
    }

    private var driftingStep: some View {
        VStack {
            Text("There it goes.").font(KFont.title(28)).foregroundStyle(Palette.text).padding(.top, 30)
            Text("Watch it for as long as you like.").font(KFont.body(15)).foregroundStyle(Palette.text2)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var restStep: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "moon").font(.system(size: 28)).foregroundStyle(Palette.gold)
            Text("Rest well.").font(KFont.title(30)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            Text("What you wrote is gone. Nothing was kept.").font(KFont.body(15)).foregroundStyle(Palette.text2)
            Spacer()
            Button("Back to Tonight") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
            Button("Release another") {
                holdProgress = 0
                driftStart = nil
                go(.write)
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.bottom, 20)
        }
        .background(Color(hex: 0x141726, opacity: 0.55).ignoresSafeArea())
    }

    // MARK: Actions

    private func fold() {
        writing = false
        Haptics.shared.tap()
        SoundEngine.shared.play(.fold, volume: 0.8)
        foldAmount = 0
        go(.folding)
        withAnimation(.easeInOut(duration: reduce ? 0.3 : 0.9)) { foldAmount = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 0.5 : 1.0)) {
            guard step == .folding else { return }
            go(.release)
        }
    }

    private func startListening() {
        holdProgress = 0
        guard !store.state.settings.tapInsteadOfHold else { return }
        breath.onComplete = { release() }
        breath.start()
    }

    private func release() {
        guard step == .release else { return }
        breath.stop()
        thought = ""
        Haptics.shared.success()
        SoundEngine.shared.play(.chime, volume: 0.6)
        SoundEngine.shared.setLoop(.wind, level: 0, fade: 1)
        driftStart = Date()
        go(.drifting)
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 4 : 9)) {
            guard step == .drifting else { return }
            go(.rest)
        }
    }
}

/// The night river with a paper lantern. Drawn, not an image, so it can move.
struct LanternScene: View {
    var driftStart: Date?
    var reduce: Bool
    var showLantern: Bool
    var glow: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduce && driftStart == nil)) { timeline in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let t = timeline.date.timeIntervalSinceReferenceDate
                // Sky
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x141726), Color(hex: 0x20223A), Color(hex: 0x2C2F4C)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                // Moon and stars
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.74, y: h * 0.09, width: 40, height: 40)), with: .color(Color(hex: 0xF0D48A)))
                let stars: [(CGFloat, CGFloat)] = [(0.12, 0.08), (0.3, 0.16), (0.55, 0.06), (0.86, 0.22), (0.18, 0.28), (0.66, 0.2), (0.42, 0.25)]
                for (i, s) in stars.enumerated() {
                    let twinkle = reduce ? 0.7 : 0.5 + 0.5 * sin(t * 0.8 + Double(i) * 1.7)
                    ctx.fill(Path(ellipseIn: CGRect(x: s.0 * w, y: s.1 * h, width: 2.4, height: 2.4)), with: .color(Color(hex: 0xC3C8D4, opacity: twinkle)))
                }
                // Far bank
                var bank = Path()
                bank.move(to: CGPoint(x: 0, y: h * 0.42))
                bank.addQuadCurve(to: CGPoint(x: w, y: h * 0.4), control: CGPoint(x: w * 0.5, y: h * 0.36))
                bank.addLine(to: CGPoint(x: w, y: h)); bank.addLine(to: CGPoint(x: 0, y: h)); bank.closeSubpath()
                ctx.fill(bank, with: .color(Color(hex: 0x2C2F4C)))
                // River
                let river = riverPath(w: w, h: h)
                ctx.fill(river, with: .linearGradient(Gradient(colors: [Color(hex: 0x6E6F9E, opacity: 0.5), Color(hex: 0x8A8CC0, opacity: 0.85)]),
                                                     startPoint: CGPoint(x: 0, y: h * 0.42), endPoint: CGPoint(x: 0, y: h)))
                // Ripples
                for i in 0..<6 {
                    let y = h * (0.55 + Double(i) * 0.075)
                    let shift = reduce ? 0 : sin(t * 0.6 + Double(i)) * 6
                    var r = Path()
                    r.move(to: CGPoint(x: riverCenter(y / h, w: w) - 26 + shift, y: y))
                    r.addLine(to: CGPoint(x: riverCenter(y / h, w: w) + 18 + shift, y: y))
                    ctx.stroke(r, with: .color(Color(hex: 0xE8F3FE, opacity: 0.18)), lineWidth: 1.4)
                }
                // Lantern
                if showLantern {
                    var progress = 0.0
                    if let start = driftStart {
                        progress = min(1, timeline.date.timeIntervalSince(start) / (reduce ? 3 : 9))
                        progress = 1 - pow(1 - progress, 1.6)
                    }
                    let y = h * (0.86 - 0.42 * progress)
                    let x = riverCenter(y / h, w: w) + (reduce ? 0 : sin(t * 0.9) * 3)
                    let scale = 1 - 0.68 * progress
                    let opacity = progress > 0.85 ? (1 - progress) / 0.15 : 1
                    let bob = reduce ? 0 : sin(t * 1.3) * 2
                    drawLantern(&ctx, at: CGPoint(x: x, y: y + bob), scale: scale, glow: glow, opacity: opacity)
                }
            }
        }
    }

    private func riverCenter(_ fy: Double, w: CGFloat) -> CGFloat {
        w * (0.5 + 0.12 * sin(fy * 9 + 0.6))
    }

    private func riverPath(w: CGFloat, h: CGFloat) -> Path {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...40 {
            let fy = 0.42 + 0.58 * Double(i) / 40
            let half = w * (0.02 + 0.2 * (fy - 0.42) / 0.58)
            let c = riverCenter(fy, w: w)
            left.append(CGPoint(x: c - half, y: h * fy))
            right.append(CGPoint(x: c + half, y: h * fy))
        }
        var p = Path()
        p.addLines(left + right.reversed())
        p.closeSubpath()
        return p
    }

    private func drawLantern(_ ctx: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, glow: Double, opacity: Double) {
        ctx.drawLayer { layer in
            layer.opacity = opacity
            layer.translateBy(x: p.x, y: p.y)
            layer.scaleBy(x: s, y: s)
            let halo = 70 + 50 * glow
            layer.fill(Path(ellipseIn: CGRect(x: -halo, y: -halo, width: halo * 2, height: halo * 2)),
                       with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD27A, opacity: 0.55 * glow), Color(hex: 0xFFD27A, opacity: 0)]),
                                             center: .zero, startRadius: 0, endRadius: halo))
            var body = Path()
            body.move(to: CGPoint(x: -20, y: -30)); body.addLine(to: CGPoint(x: 20, y: -30))
            body.addLine(to: CGPoint(x: 25, y: 22)); body.addLine(to: CGPoint(x: -25, y: 22)); body.closeSubpath()
            layer.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF3D6), Color(hex: 0xF6CE87)]),
                                                  startPoint: CGPoint(x: 0, y: -30), endPoint: CGPoint(x: 0, y: 22)))
            layer.fill(Path(roundedRect: CGRect(x: -30, y: 20, width: 60, height: 8), cornerRadius: 3), with: .color(Color(hex: 0x5B3D2F)))
            layer.fill(Path(ellipseIn: CGRect(x: -5, y: -10, width: 10, height: 16)), with: .color(Color(hex: 0xE08A6F, opacity: 0.6 + 0.4 * glow)))
        }
    }
}
