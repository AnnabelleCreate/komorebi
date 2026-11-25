import SwiftUI

/// Karesansui · Japanese dry garden.
struct GardenView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce
    @State private var garden = GardenController()

    private var palette: GardenPalette {
        switch store.state.settings.gardenLight {
        case .night: return .night
        case .bright: return .bright
        case .matchPhone: return UITraitCollection.current.userInterfaceStyle == .light || systemIsLight ? .bright : .night
        }
    }

    private var systemIsLight: Bool {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.traitCollection.userInterfaceStyle == .light
    }

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 402
            let logicalHeight = geo.size.height / max(k, 0.01)
            ZStack(alignment: .top) {
                sand(k: k)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(rakeGesture(k: k))
                    .accessibilityElement()
                    .accessibilityLabel(garden.accessibilityDescription)
                    .accessibilityHint(store.state.settings.oneTapRaking
                                       ? "One-tap raking buttons are below."
                                       : "Double-tap and hold, then drag to rake. Or use the actions to rake for you.")
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityActions {
                        Button("Rake a line") { garden.rakeLine() }
                        Button("Rings around the large stone") { garden.rippleStone(0) }
                        Button("Rings around the middle stone") { garden.rippleStone(1) }
                        Button("Rings around the small stone") { garden.rippleStone(2) }
                        if garden.pathMode { Button("Trace the next part") { garden.traceNextPart() } }
                        Button("Smooth it away") { garden.smooth() }
                    }

                overlays

                if garden.loadFailed {
                    VStack(spacing: 12) {
                        Text("The sand couldn’t be prepared.").font(KFont.heading(20)).foregroundStyle(Palette.text)
                        Text("Your phone may be low on memory. Closing other apps can help.")
                            .font(KFont.body(14)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
                        Button("Try again") { garden.retrySetUp() }.buttonStyle(PrimaryButtonStyle(fullWidth: false))
                        Button("Leave the garden") { dismiss() }.buttonStyle(GhostButtonStyle())
                    }
                    .padding(24)
                    .kCard(radius: 22)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.background.opacity(0.6).ignoresSafeArea())
                } else if garden.isLoading && garden.layer != .intro {
                    LoadingView(message: "Smoothing the sand…", style: .fullScreen, delay: 0.25,
                                slowActionTitle: "Leave the garden", slowAction: { dismiss() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(true)
                }
            }
            .onAppear {
                garden.reduceMotion = reduce
                garden.steady = store.state.settings.steady
                garden.setUp(height: logicalHeight, palette: palette) { message in
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
                garden.start()
            }
            .onChange(of: geo.size) { _, size in
                garden.setUp(height: size.height / max(size.width / 402, 0.01), palette: palette) { message in
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
        }
        .ignoresSafeArea()
        .background(Color(uiColor: palette.sandLo).ignoresSafeArea())
        .statusBarHidden(true)
        .onDisappear { garden.stop() }
        .onChange(of: store.state.settings.steady) { _, value in garden.steady = value }
        .onChange(of: reduce) { _, value in garden.reduceMotion = value }
    }

    // MARK: Sand

    @ViewBuilder
    private func sand(k: CGFloat) -> some View {
        let p = garden.engine?.palette ?? palette
        let tick = garden.frame
        ZStack(alignment: .topLeading) {
            if let base = garden.engine?.base {
                Image(decorative: base, scale: 1).resizable().interpolation(.medium)
            }
            if let ridge = garden.ridge { Image(decorative: ridge, scale: 1).resizable().interpolation(.medium) }
            if let groove = garden.groove { Image(decorative: groove, scale: 1).resizable().interpolation(.medium) }
            Canvas { ctx, _ in
                _ = tick
                ctx.scaleBy(x: k, y: k)
                if let g = garden.guide, garden.pathMode, garden.layer == .garden {
                    drawGuide(&ctx, g, covered: garden.covered, alpha: garden.guideAlpha, color: p.guide)
                }
                if let engine = garden.engine {
                    drawLeaf(&ctx, engine.leaf, p)
                    drawRocks(&ctx, engine.rocks, p)
                    if let y = garden.sweepY { drawSweep(&ctx, y: y, bright: p.isBright) }
                    if let head = garden.head, let dir = garden.direction {
                        for t in engine.tines(at: head, normal: CGVector(dx: -dir.dy, dy: dir.dx)) {
                            ctx.fill(Path(ellipseIn: CGRect(x: t.x - 2.6, y: t.y - 2.6, width: 5.2, height: 5.2)), with: .color(p.head))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func rakeGesture(k: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let p = CGPoint(x: value.location.x / k, y: value.location.y / k)
                if value.translation == .zero { garden.touchDown(p) } else { garden.touchMoved(p) }
            }
            .onEnded { _ in garden.touchUp() }
    }

    private func drawGuide(_ ctx: inout GraphicsContext, _ pts: [CGPoint], covered: [Bool], alpha: Double, color: Color) {
        var path = Path()
        var i = 0
        while i < pts.count {
            if !(covered.indices.contains(i) && covered[i]) {
                path.addEllipse(in: CGRect(x: pts[i].x - 1.7, y: pts[i].y - 1.7, width: 3.4, height: 3.4))
            }
            i += 3
        }
        ctx.fill(path, with: .color(color.opacity(alpha)))
    }

    private func polygon(_ pts: [CGPoint], dx: CGFloat = 0, dy: CGFloat = 0) -> Path {
        var path = Path()
        for (i, q) in pts.enumerated() {
            let pt = CGPoint(x: q.x + dx, y: q.y + dy)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func drawRocks(_ ctx: inout GraphicsContext, _ rocks: [GardenRock], _ p: GardenPalette) {
        for rock in rocks {
            let u = rock.r / 40
            let outer = polygon(rock.outer)
            ctx.fill(polygon(rock.outer, dx: -7 * u - 2, dy: 8 * u + 2), with: .color(p.cast))
            ctx.drawLayer { layer in
                layer.clip(to: outer)
                layer.fill(outer, with: .color(p.rockShade))
                layer.fill(polygon(rock.outer, dx: 5 * u + 1, dy: -6 * u - 1), with: .color(p.rock))
                layer.stroke(polygon(rock.outer, dx: -1.6, dy: 1.6), with: .color(p.rim), lineWidth: 2.2)
            }
            ctx.stroke(outer, with: .color(p.edge), lineWidth: 1.5)
            for contour in rock.contours { ctx.stroke(polygon(contour), with: .color(p.contour), lineWidth: 1.1) }
        }
    }

    private func leafPath(_ r: CGFloat) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.12), endAngle: .radians(.pi * 1.47), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: -r * 0.62))
        path.addArc(center: .zero, radius: r, startAngle: .radians(.pi * 1.53), endAngle: .radians(.pi * 1.88), clockwise: false)
        path.closeSubpath()
        return path
    }

    private func drawLeaf(_ ctx: inout GraphicsContext, _ leaf: GardenLeaf, _ p: GardenPalette) {
        ctx.drawLayer { layer in
            layer.translateBy(x: leaf.x, y: leaf.y)
            layer.rotate(by: .radians(leaf.angle))
            layer.drawLayer { shadow in
                shadow.addFilter(.blur(radius: 2))
                shadow.translateBy(x: 2, y: 3)
                shadow.fill(leafPath(leaf.r), with: .color(p.shadow))
            }
            layer.fill(leafPath(leaf.r), with: .color(p.leaf))
            var stem = Path()
            stem.move(to: .zero)
            stem.addLine(to: CGPoint(x: 0, y: leaf.r * 0.9))
            layer.stroke(stem, with: .color(p.leafLine), lineWidth: 1.2)
        }
    }

    private func drawSweep(_ ctx: inout GraphicsContext, y: CGFloat, bright: Bool) {
        let glow = Gradient(stops: [
            .init(color: Palette.text.opacity(0), location: 0),
            .init(color: Palette.text.opacity(bright ? 0.45 : 0.16), location: 0.75),
            .init(color: .clear, location: 1),
        ])
        ctx.fill(Path(CGRect(x: 0, y: y - 26, width: 402, height: 36)),
                 with: .linearGradient(glow, startPoint: CGPoint(x: 0, y: y - 26), endPoint: CGPoint(x: 0, y: y + 10)))
        ctx.fill(Path(roundedRect: CGRect(x: -4, y: y + 4, width: 410, height: 7), cornerRadius: 3), with: .color(Color(hex: 0x1C2139, opacity: 0.88)))
    }

    // MARK: Controls

    private var isBright: Bool { (garden.engine?.palette ?? palette).isBright }
    private var buttonFill: Color { isBright ? Color(hex: 0x1C2139, opacity: 0.14) : Color(hex: 0x1C2139, opacity: 0.6) }
    private var buttonInk: Color { isBright ? Color(hex: 0x1C2139) : Palette.text }

    private func roundButton(_ systemImage: String, _ label: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.shared.tap(); action() }) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(on ? (isBright ? Palette.text : Color(hex: 0x1C2139)) : buttonInk)
                .frame(width: 44, height: 44)
                .background(Circle().fill(on ? (isBright ? Color(hex: 0x1C2139) : Palette.gold) : buttonFill))
                .background(Circle().fill(.ultraThinMaterial).opacity(on ? 0 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private var overlays: some View {
        switch garden.layer {
        case .intro: intro.transition(.opacity)
        case .garden: gardenControls.transition(.opacity)
        case .rest: rest.transition(.opacity)
        }
    }

    private var intro: some View {
        VStack {
            HStack {
                roundButton("chevron.left", "Leave the garden") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Karesansui · Japanese dry garden")
                Text("Sand garden").font(KFont.title(28)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("Rake slow lines. Tap a stone to ripple it. Your garden stays until you smooth it away.")
                    .font(KFont.body(16)).foregroundStyle(Palette.text2)
                HStack(spacing: 10) {
                    Button("Trace a path") { withAnimation(Motion.ease(reduce)) { garden.begin(tracing: true) } }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Rake freely") { withAnimation(Motion.ease(reduce)) { garden.begin(tracing: false) } }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: 0x1C2139, opacity: 0.94)))
            .padding(.horizontal, 12)
            .padding(.bottom, 30)
        }
    }

    private var gardenControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                roundButton("xmark", "Done") { withAnimation(Motion.ease(reduce)) { garden.finish() } }
                Spacer()
                roundButton("hand.tap", "One-tap raking", on: store.state.settings.oneTapRaking) {
                    store.state.settings.oneTapRaking.toggle()
                    UIAccessibility.post(notification: .announcement,
                                         argument: store.state.settings.oneTapRaking ? "One-tap raking on. Buttons to rake lines and rings are at the bottom." : "One-tap raking off.")
                }
                roundButton("scribble.variable", "Trace a path", on: garden.pathMode) { garden.togglePath() }
                roundButton(garden.soundOn ? "speaker.wave.2" : "speaker.slash", garden.soundOn ? "Mute sound" : "Turn sound on") {
                    garden.soundOn.toggle()
                    if !garden.soundOn { SoundEngine.shared.setLoop(.sand, level: 0) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)

            if !garden.label.isEmpty {
                Text(garden.label)
                    .font(KFont.medium(16))
                    .foregroundStyle(isBright ? Color(hex: 0x1C2139) : Palette.text)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 16).fill(isBright ? Color(hex: 0x1C2139, opacity: 0.12) : Color(hex: 0x1C2139, opacity: 0.55)))
                    .padding(.top, 14)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            Spacer()

            if !garden.hinted && !garden.pathMode && !store.state.settings.oneTapRaking {
                Text("Drag slowly")
                    .font(KFont.medium(18))
                    .foregroundStyle((isBright ? Color(hex: 0x1C2139) : Palette.text).opacity(0.8))
                    .transition(.opacity)
                    .accessibilityHidden(true)
                Spacer()
            }

            if store.state.settings.oneTapRaking { oneTapButtons.padding(.bottom, 14) }

            HStack(spacing: 10) {
                Button { garden.smooth() } label: {
                    Label("Smooth it away", systemImage: "wind")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                Button("Done") { withAnimation(Motion.ease(reduce)) { garden.finish() } }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                    .background(Capsule().fill(Color(hex: 0x1C2139, opacity: isBright ? 0.9 : 0.6)))
            }
            .padding(.bottom, 36)
        }
        .animation(Motion.ease(reduce), value: garden.label)
        .animation(Motion.ease(reduce), value: garden.hinted)
    }

    private var oneTapButtons: some View {
        let g = garden
        var chips: [OneTapChip] = []
        if g.pathMode && g.guide != nil {
            chips.append(OneTapChip(title: "Trace the next part", label: "Trace the next part of the path", run: { g.traceNextPart() }))
        }
        chips.append(OneTapChip(title: "Rake a line", label: "Rake a line", run: { g.rakeLine() }))
        chips.append(OneTapChip(title: "Rings: large stone", label: "Rake rings around the large stone", run: { g.rippleStone(0) }))
        chips.append(OneTapChip(title: "Rings: middle stone", label: "Rake rings around the middle stone", run: { g.rippleStone(1) }))
        chips.append(OneTapChip(title: "Rings: small stone", label: "Rake rings around the small stone", run: { g.rippleStone(2) }))
        return FlowRow(spacing: 8) {
            ForEach(chips.indices, id: \.self) { i in
                Button(chips[i].title) { Haptics.shared.tap(); chips[i].run() }
                    .font(KFont.medium(14))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1C2139, opacity: 0.92)))
                    .accessibilityLabel(chips[i].label)
            }
        }
        .padding(.horizontal, 16)
    }

    private var rest: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "moon").font(.system(size: 28)).foregroundStyle(Palette.gold)
            Text("Rest well.").font(KFont.title(28)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            Text("Your garden will be here next time.").font(KFont.body(16)).foregroundStyle(Palette.text2)
            Spacer()
            Button("Rake again") { withAnimation(Motion.ease(reduce)) { garden.wake() } }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            Button("Leave the garden") { dismiss() }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x141726, opacity: 0.93))
    }
}

private struct OneTapChip {
    var title: String
    var label: String
    var run: () -> Void
}

/// Wraps children onto new lines when they don't fit.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.reduce(CGFloat(0)) { max($0, $1.width) }
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: [Int] = []
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.isEmpty ? size.width : rowWidth + spacing + size.width
            if needed > width && !current.isEmpty {
                rows.append((current, rowWidth, rowHeight))
                current = [index]; rowWidth = size.width; rowHeight = size.height
            } else {
                current.append(index); rowWidth = needed; rowHeight = max(rowHeight, size.height)
            }
        }
        if !current.isEmpty { rows.append((current, rowWidth, rowHeight)) }
        return rows
    }
}
