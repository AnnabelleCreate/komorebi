import SwiftUI

/// Lantern release · inspired by tōrō nagashi.
/// Write one thought, fold it into the paper lantern, breathe out to send it down the river.
/// The words are never saved: they live only in this view and are cleared when the lantern drifts away.
struct LanternView: View {
    enum Step: Equatable { case begin, write, folding, release, drifting, rest }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var step: Step = .begin
    @State private var thought = ""
    @State private var breath = BreathDetector()
    @State private var holdProgress: Double = 0
    @State private var holding = false
    @State private var driftStart: Date?
    /// 0 = note sits in its card, 1 = folded and tucked inside the lantern.
    @State private var fold: Double = 0
    @State private var noteInLantern = false
    @FocusState private var writing: Bool

    private let limit = 160

    var body: some View {
        GeometryReader { geo in
            let panelHeight = panelHeight(for: geo.size.height)
            ZStack(alignment: .top) {
                Palette.card.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    switch step {
                    case .begin: beginStep(panelHeight)
                    case .write: writeStep(panelHeight)
                    case .folding: foldingStep(panelHeight)
                    case .release: releaseStep(panelHeight)
                    case .drifting: driftingStep(panelHeight)
                    case .rest: restStep(panelHeight)
                    }
                }
                .animation(Motion.ease(reduce, duration: 0.6), value: step)
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

    private func panelHeight(for height: CGFloat) -> CGFloat {
        switch step {
        case .write: return writing ? 150 : min(220, height * 0.26)
        default: return min(320, height * 0.36)
        }
    }

    private var glow: Double {
        switch step {
        case .begin, .write: return 0.25
        case .folding: return noteInLantern ? 0.7 : 0.3
        case .release: return 0.55 + 0.45 * max(breath.progress, holdProgress)
        default: return 1
        }
    }

    private func go(_ next: Step) {
        withAnimation(Motion.ease(reduce, duration: 0.6)) { step = next }
    }

    // MARK: Scene panel

    private func scene(_ height: CGFloat, showLantern: Bool = true) -> some View {
        LanternScene(driftStart: driftStart, reduce: reduce, showLantern: showLantern, glow: glow,
                     holding: holding, noteInside: noteInLantern || step == .release || step == .drifting)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if step == .write { go(.begin) } else { dismiss() }
            } label: {
                Image(systemName: step == .begin || step == .write ? "arrow.left" : "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(step == .write ? "Back" : "Close")
            Text("Lantern release").font(KFont.heading(20)).foregroundStyle(Palette.text)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    // MARK: Steps

    private func beginStep(_ panel: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            scene(panel)
            VStack(alignment: .leading, spacing: 8) {
                Text("A little less to carry.").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("Put a thought into a paper lantern. Let the river carry it for a while.")
                    .font(KFont.body(16)).foregroundStyle(Palette.text2)
                Text("ABOUT THIS RITUAL").font(KFont.medium(14)).tracking(1.2).foregroundStyle(Palette.gold).padding(.top, 18)
                Text("Inspired by tōrō nagashi, Japan’s lantern-floating custom of remembrance. This is a quiet, personal moment of letting go.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Spacer(minLength: 12)
            Button("Begin") { go(.write); SoundEngine.shared.play(.tap, volume: 0.6) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .transition(Motion.screen(reduce))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR THOUGHT").font(KFont.medium(14, relativeTo: .caption)).tracking(1).foregroundStyle(Palette.gold)
            ZStack(alignment: .topLeading) {
                if thought.isEmpty {
                    Text("A worry, a thank-you, something unfinished…")
                        .font(KFont.body(16))
                        .foregroundStyle(Palette.text3)
                        .padding(.top, 8).padding(.leading, 5)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $thought)
                    .font(KFont.body(16))
                    .foregroundStyle(Palette.text)
                    .scrollContentBackground(.hidden)
                    .focused($writing)
                    .accessibilityLabel("Your thought")
                    .onChange(of: thought) { _, value in
                        if value.count > limit { thought = String(value.prefix(limit)) }
                    }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 190, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.background))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.outlineStrong, lineWidth: 1))
    }

    private func writeStep(_ panel: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The lantern stays visible above the note, waiting for it.
            scene(panel)
            VStack(alignment: .leading, spacing: 8) {
                Text("What’s on your mind?").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("A worry, a thought, or a positive moment. How are you feeling today?")
                    .font(KFont.body(14)).foregroundStyle(Palette.text2)
                noteCard.padding(.top, 8)
                HStack {
                    Text("Not saved anywhere").font(KFont.body(14)).foregroundStyle(Palette.text3)
                    Spacer()
                    Text("\(thought.count)/\(limit)").font(KFont.body(14)).foregroundStyle(Palette.text3)
                        .accessibilityLabel("\(limit - thought.count) characters left")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Button("Fold into a lantern") { startFold() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Release without words") { startFold() }
                    .buttonStyle(GhostButtonStyle())
                Text("Your words disappear when you release them or leave this ritual.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text3).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .transition(Motion.screen(reduce))
        .onAppear { writing = true }
    }

    /// The note folds in half twice, shrinks, and travels up into the lantern.
    private func foldingStep(_ panel: CGFloat) -> some View {
        GeometryReader { geo in
            let lanternPoint = CGPoint(x: geo.size.width / 2, y: panel * 0.74)
            let start = CGPoint(x: geo.size.width / 2, y: panel + 140)
            let t = fold
            let x = start.x + (lanternPoint.x - start.x) * t
            let y = start.y + (lanternPoint.y - start.y) * t
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    scene(panel)
                    Text(noteInLantern ? "Your thought is inside." : "Folding it into the lantern…")
                        .font(KFont.body(16)).foregroundStyle(Palette.text2)
                        .padding(.top, 24)
                        .accessibilityAddTraits(.updatesFrequently)
                    Spacer()
                }
                FoldedNote(progress: t, reduce: reduce)
                    .frame(width: 300, height: 170)
                    .scaleEffect(1 - 0.92 * t)
                    .opacity(noteInLantern ? 0 : 1)
                    .position(x: x, y: y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .transition(.opacity)
    }

    private func releaseStep(_ panel: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Blow softly. Let it go.").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text(releaseInstruction).font(KFont.body(14)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            scene(panel)
                .overlay(alignment: .bottom) { releaseProgress.padding(.bottom, 12) }
                .contentShape(Rectangle())
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
                .accessibilityLabel(store.state.settings.tapInsteadOfHold ? "Lantern. Tap to release it." : "Lantern. Press and hold while you breathe out to release it.")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { release() }
            if store.state.settings.haptics {
                Label("Gentle haptics on", systemImage: "iphone.radiowaves.left.and.right")
                    .font(KFont.body(14)).foregroundStyle(Palette.background)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Palette.surface))
                    .padding(.top, 16)
            }
            Spacer()
            Button("Tap to release instead") { release() }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .transition(Motion.screen(reduce))
        .onAppear(perform: startListening)
        .onDisappear { breath.stop() }
    }

    private var releaseProgress: some View {
        let progress = max(breath.progress, holdProgress)
        return Capsule()
            .fill(Palette.text.opacity(0.18))
            .frame(width: 120, height: 4)
            .overlay(alignment: .leading) { Capsule().fill(Palette.gold).frame(width: 120 * progress, height: 4) }
            .opacity(progress > 0.01 ? 1 : 0)
    }

    private var releaseInstruction: String {
        if store.state.settings.tapInsteadOfHold { return "Breathe out slowly, then tap the lantern." }
        switch breath.status {
        case .listening: return "One gentle breath toward your phone, or press and hold the lantern."
        case .denied, .unavailable: return "Press and hold the lantern while you breathe out."
        default: return "One gentle breath toward your phone."
        }
    }

    private func driftingStep(_ panel: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Let the river take it.").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("You don’t need to do anything now.").font(KFont.body(14)).foregroundStyle(Palette.text2)
            }
            .padding(.vertical, 18)
            scene(panel)
            Text("Nothing to hold on to.").font(KFont.body(16)).foregroundStyle(Palette.text2).padding(.top, 40)
            Spacer()
            Button("Done for tonight") { go(.rest) }.buttonStyle(GhostButtonStyle())
            Text("Leave whenever you’re ready.").font(KFont.body(14)).foregroundStyle(Palette.text3).padding(.bottom, 24)
        }
        .transition(.opacity)
    }

    private func restStep(_ panel: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("For now, you can rest.").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("The thought has passed.\nThere’s nothing you need to keep.").font(KFont.body(14)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
            }
            .padding(.vertical, 18)
            scene(panel, showLantern: false)
            VStack(spacing: 6) {
                Text("Your words weren’t saved.").font(KFont.body(16)).foregroundStyle(Palette.gold)
                Text("No history. No streak. Just this moment.").font(KFont.body(14)).foregroundStyle(Palette.text2)
            }
            .padding(.top, 36)
            Spacer()
            Button("Rest for tonight") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 16)
            Button("Release another thought") {
                holdProgress = 0
                driftStart = nil
                fold = 0
                noteInLantern = false
                go(.write)
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    // MARK: Actions

    private func startFold() {
        writing = false
        Haptics.shared.tap()
        SoundEngine.shared.play(.fold, volume: 0.8)
        fold = 0
        noteInLantern = false
        go(.folding)
        let travel = reduce ? 0.35 : 1.6
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: travel)) { fold = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + travel) {
            guard step == .folding else { return }
            withAnimation(.easeOut(duration: 0.5)) { noteInLantern = true }
            Haptics.shared.grain(0.5)
            SoundEngine.shared.play(.tap, volume: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + travel + 1.0) {
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
        holding = false
        driftStart = Date()
        go(.drifting)
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 5 : 11)) {
            guard step == .drifting else { return }
            go(.rest)
        }
    }
}

/// A sheet of paper folding in half twice as it shrinks.
private struct FoldedNote: View {
    var progress: Double
    var reduce: Bool
    var body: some View {
        let firstFold = min(1, progress / 0.4)
        let secondFold = max(0, min(1, (progress - 0.35) / 0.4))
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: 0xF4E8D0))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(Color(hex: 0x2B2418, opacity: 0.25)).frame(width: i == 3 ? 120 : 220, height: 3)
                        }
                    }
                    .padding(22)
                    .opacity(1 - firstFold)
                }
                .scaleEffect(x: 1 - 0.5 * firstFold, y: 1 - 0.5 * secondFold)
                .rotation3DEffect(.degrees(reduce ? 0 : 40 * sin(.pi * firstFold)), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(reduce ? 0 : 40 * sin(.pi * secondFold)), axis: (x: 1, y: 0, z: 0))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        }
    }
}

/// The night river with a paper lantern. The river narrows into the distance and ends at the far bank on the horizon,
/// so a drifting lantern grows smaller and disappears behind the land.
struct LanternScene: View {
    var driftStart: Date?
    var reduce: Bool
    var showLantern: Bool
    var glow: Double
    var holding: Bool = false
    var noteInside: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduce && driftStart == nil)) { timeline in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let t = timeline.date.timeIntervalSinceReferenceDate
                let horizon = h * 0.42

                // Sky
                ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon + 2)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x1C2139), Color(hex: 0x30345A)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
                // Moon and stars
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.76, y: h * 0.1, width: h * 0.1, height: h * 0.1)), with: .color(Palette.gold))
                let stars: [(CGFloat, CGFloat)] = [(0.12, 0.08), (0.3, 0.17), (0.55, 0.06), (0.9, 0.3), (0.2, 0.3), (0.64, 0.22)]
                for (i, s) in stars.enumerated() {
                    let twinkle = reduce ? 0.6 : 0.4 + 0.4 * sin(t * 0.8 + Double(i) * 1.7)
                    ctx.fill(Path(ellipseIn: CGRect(x: s.0 * w, y: s.1 * h, width: 2, height: 2)), with: .color(Palette.text2.opacity(twinkle)))
                }

                // Land below the horizon
                ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .color(Color(hex: 0x2B2F4D)))

                // River: wide at the bottom, narrowing to a point at the horizon
                ctx.fill(riverPath(w: w, h: h, horizon: horizon), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x5C5E8A), Color(hex: 0x7B7DAA)]),
                    startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
                for i in 0..<5 {
                    let fy = 0.55 + Double(i) * 0.09
                    let cx = riverCenter(fy, w: w), half = riverHalfWidth(fy, w: w)
                    let shift = reduce ? 0 : sin(t * 0.6 + Double(i)) * half * 0.15
                    var r = Path()
                    r.move(to: CGPoint(x: cx - half * 0.35 + shift, y: h * fy))
                    r.addLine(to: CGPoint(x: cx + half * 0.2 + shift, y: h * fy))
                    ctx.stroke(r, with: .color(Palette.surface.opacity(0.2)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }

                // Far hills sit on the horizon and hide where the river ends
                var hills = Path()
                hills.move(to: CGPoint(x: 0, y: horizon + 4))
                hills.addCurve(to: CGPoint(x: w * 0.42, y: horizon - h * 0.03), control1: CGPoint(x: w * 0.12, y: horizon - h * 0.16), control2: CGPoint(x: w * 0.3, y: horizon - h * 0.12))
                hills.addCurve(to: CGPoint(x: w, y: horizon - h * 0.08), control1: CGPoint(x: w * 0.6, y: horizon + h * 0.03), control2: CGPoint(x: w * 0.78, y: horizon - h * 0.2))
                hills.addLine(to: CGPoint(x: w, y: horizon + 4))
                hills.closeSubpath()
                ctx.fill(hills, with: .color(Color(hex: 0x1A1D31)))

                // Grass tufts
                for (fx, fy) in [(0.14, 0.72), (0.82, 0.62), (0.1, 0.9), (0.88, 0.86)] as [(CGFloat, CGFloat)] {
                    var g = Path()
                    let x = w * fx, y = h * fy
                    g.move(to: CGPoint(x: x - 6, y: y - 12)); g.addLine(to: CGPoint(x: x, y: y)); g.addLine(to: CGPoint(x: x + 5, y: y - 14))
                    ctx.stroke(g, with: .color(Palette.text3.opacity(0.6)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }

                // Lantern
                if showLantern {
                    var progress = 0.0
                    if let start = driftStart {
                        progress = min(1, timeline.date.timeIntervalSince(start) / (reduce ? 4 : 10))
                        progress = 1 - pow(1 - progress, 1.4)
                    }
                    // Travels from near the bottom up the river to the horizon.
                    let fy = 0.78 - (0.78 - 0.42) * progress
                    let y = h * fy
                    let x = riverCenter(fy, w: w) + (reduce ? 0 : sin(t * 0.9) * 2)
                    let scale = (h / 320) * (1 - 0.9 * progress)
                    let bob = reduce ? 0 : sin(t * 1.3) * 1.5 * (1 - progress)
                    ctx.drawLayer { layer in
                        // Anything past the horizon is hidden: the lantern slips behind the far bank.
                        layer.clip(to: Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)))
                        drawLantern(&layer, at: CGPoint(x: x, y: y + bob), scale: scale)
                    }
                }
            }
        }
    }

    private func riverCenter(_ fy: Double, w: CGFloat) -> CGFloat {
        // Winding S-curve that settles toward the vanishing point.
        let d = (fy - 0.42) / 0.58
        return w * (0.46 + 0.14 * d * sin(d * 7.5 + 0.4))
    }

    private func riverHalfWidth(_ fy: Double, w: CGFloat) -> CGFloat {
        let d = max(0, (fy - 0.42) / 0.58)
        return w * (0.004 + 0.2 * pow(d, 1.3))
    }

    private func riverPath(w: CGFloat, h: CGFloat, horizon: CGFloat) -> Path {
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...48 {
            let fy = 0.42 + 0.58 * Double(i) / 48
            let c = riverCenter(fy, w: w), half = riverHalfWidth(fy, w: w)
            left.append(CGPoint(x: c - half, y: max(horizon, h * fy)))
            right.append(CGPoint(x: c + half, y: max(horizon, h * fy)))
        }
        var p = Path()
        p.addLines(left + right.reversed())
        p.closeSubpath()
        return p
    }

    private func drawLantern(_ ctx: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        ctx.drawLayer { layer in
            layer.translateBy(x: p.x, y: p.y)
            layer.scaleBy(x: s, y: s)
            let halo = 46 + 30 * glow
            layer.fill(Path(ellipseIn: CGRect(x: -halo, y: -halo - 14, width: halo * 2, height: halo * 2)),
                       with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD27A, opacity: 0.45 * glow), Color(hex: 0xFFD27A, opacity: 0)]),
                                             center: CGPoint(x: 0, y: -14), startRadius: 0, endRadius: halo))
            // Reflection on the water
            for i in 0..<3 {
                let yy = 10 + CGFloat(i) * 6
                let ww = 22 - CGFloat(i) * 5
                layer.fill(Path(roundedRect: CGRect(x: -ww / 2, y: yy, width: ww, height: 2.2), cornerRadius: 1.1),
                           with: .color(Palette.gold.opacity(0.5 * glow)))
            }
            // Base
            layer.fill(Path(roundedRect: CGRect(x: -22, y: 0, width: 44, height: 7), cornerRadius: 2), with: .color(Color(hex: 0x5B3D2F)))
            // Paper box, slightly isometric
            var front = Path()
            front.move(to: CGPoint(x: -16, y: 0)); front.addLine(to: CGPoint(x: 6, y: 0))
            front.addLine(to: CGPoint(x: 6, y: -28)); front.addLine(to: CGPoint(x: -16, y: -28)); front.closeSubpath()
            var side = Path()
            side.move(to: CGPoint(x: 6, y: 0)); side.addLine(to: CGPoint(x: 17, y: -5))
            side.addLine(to: CGPoint(x: 17, y: -33)); side.addLine(to: CGPoint(x: 6, y: -28)); side.closeSubpath()
            var top = Path()
            top.move(to: CGPoint(x: -16, y: -28)); top.addLine(to: CGPoint(x: 6, y: -28))
            top.addLine(to: CGPoint(x: 17, y: -33)); top.addLine(to: CGPoint(x: -5, y: -33)); top.closeSubpath()
            let lit = 0.55 + 0.45 * glow
            layer.fill(front, with: .color(Color(hex: 0xF4E8D0).opacity(0.85 + 0.15 * lit)))
            layer.fill(side, with: .color(Color(hex: 0xE2C79A)))
            layer.fill(top, with: .color(Color(hex: 0xFFF3D6)))
            // Flame
            var flame = Path()
            flame.move(to: CGPoint(x: -5, y: -6))
            flame.addQuadCurve(to: CGPoint(x: -5, y: -19), control: CGPoint(x: -11, y: -12))
            flame.addQuadCurve(to: CGPoint(x: -5, y: -6), control: CGPoint(x: 1, y: -12))
            layer.fill(flame, with: .color(Color(hex: 0xE08A6F, opacity: 0.5 + 0.5 * glow)))
            // The folded note, once it's inside
            if noteInside {
                layer.fill(Path(roundedRect: CGRect(x: -12, y: -26, width: 8, height: 6), cornerRadius: 1), with: .color(Color(hex: 0xFFFFFF, opacity: 0.85)))
            }
        }
    }
}
