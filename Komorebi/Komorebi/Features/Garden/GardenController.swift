import Observation
import QuartzCore
import SwiftUI

/// Steady hands presets (One Euro filter), matching the web prototype.
struct SteadyConfig {
    var minCutoff: Double
    var beta: Double
    var turnLength: CGFloat
    var speed: CGFloat
    var cover: CGFloat
    var tapMove: CGFloat
    var tapTime: Double

    static func preset(_ level: SteadyLevel) -> SteadyConfig? {
        switch level {
        case .off: return nil
        case .gentle: return SteadyConfig(minCutoff: 1, beta: 0.0008, turnLength: 7, speed: 280, cover: 24, tapMove: 16, tapTime: 0.65)
        case .strong: return SteadyConfig(minCutoff: 0.45, beta: 0.0004, turnLength: 9, speed: 260, cover: 30, tapMove: 24, tapTime: 0.9)
        case .steadiest: return SteadyConfig(minCutoff: 0.25, beta: 0.0002, turnLength: 11, speed: 240, cover: 34, tapMove: 30, tapTime: 1.1)
        }
    }

    static let unfiltered = SteadyConfig(minCutoff: 0, beta: 0, turnLength: 5, speed: 300, cover: 20, tapMove: 10, tapTime: 0.45)
}

/// Smooths shaky input without adding lag to fast, deliberate strokes.
struct OneEuroFilter {
    var config: SteadyConfig
    private var value: CGPoint?
    private var speed: Double = 0
    private var lastTime: Double = 0

    init(config: SteadyConfig) { self.config = config }

    private static func alpha(_ cutoff: Double, _ dt: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }

    mutating func filter(_ p: CGPoint, time: Double) -> CGPoint {
        guard let v = value else { value = p; lastTime = time; return p }
        let dt = max(1.0 / 240, time - lastTime)
        lastTime = time
        let instant = Double(hypot(p.x - v.x, p.y - v.y)) / dt
        speed += OneEuroFilter.alpha(1, dt) * (instant - speed)
        let a = CGFloat(OneEuroFilter.alpha(config.minCutoff + config.beta * speed, dt))
        let next = CGPoint(x: v.x + a * (p.x - v.x), y: v.y + a * (p.y - v.y))
        value = next
        return next
    }
}

private final class DisplayLinkProxy: NSObject {
    var onFrame: ((CFTimeInterval) -> Void)?
    @objc func step(_ link: CADisplayLink) { onFrame?(link.targetTimestamp) }
}

/// Runs the sand garden: input, smoothing, animations, tracing and sound.
@Observable
final class GardenController {
    enum Layer { case intro, garden, rest }

    // What the UI shows
    var layer: Layer = .intro
    var pathMode = false
    var soundOn = true
    var label = ""
    var hinted = false
    private(set) var frame = 0
    private(set) var ridge: CGImage?
    private(set) var groove: CGImage?
    private(set) var tracePercent = 0

    @ObservationIgnored private(set) var engine: GardenEngine?
    @ObservationIgnored private var link: CADisplayLink?
    private let proxy = DisplayLinkProxy()
    @ObservationIgnored private var dirty = true

    // Stroke state (design-space points)
    @ObservationIgnored private(set) var head: CGPoint?
    @ObservationIgnored private(set) var direction: CGVector?
    @ObservationIgnored private var target: CGPoint?
    @ObservationIgnored private var raw: CGPoint?
    @ObservationIgnored private var previousTines: [CGPoint]?
    @ObservationIgnored private var isDown = false
    @ObservationIgnored private var tap: (rock: GardenRock, at: CGPoint, time: Double)?
    @ObservationIgnored private var filter: OneEuroFilter?
    @ObservationIgnored private var travel: CGFloat = 0
    @ObservationIgnored private var activeSeconds: Double = 0
    @ObservationIgnored private var nudged = false
    @ObservationIgnored private var lastTime: Double = CACurrentMediaTime()

    // Tracing
    @ObservationIgnored private(set) var guide: [CGPoint]?
    @ObservationIgnored private(set) var covered: [Bool] = []
    @ObservationIgnored private var coveredCount = 0
    @ObservationIgnored private var maxCovered = 0
    @ObservationIgnored private var doneAt: Double?
    @ObservationIgnored private(set) var guideAlpha: Double = 1
    @ObservationIgnored private var order: [GardenShape] = GardenShape.allCases.shuffled()
    @ObservationIgnored private var orderIndex = 0

    // Animations
    @ObservationIgnored private var ripples: [(rock: GardenRock, start: Double, angle: CGFloat)] = []
    @ObservationIgnored private var autoRakes: [(points: [CGPoint], start: Double, index: Int, done: (() -> Void)?)] = []
    @ObservationIgnored private(set) var sweepY: CGFloat?
    @ObservationIgnored private var sweepStart: Double?
    @ObservationIgnored private var lineRow = 0
    @ObservationIgnored private var announce: (String) -> Void = { _ in }

    var reduceMotion = false
    var steady: SteadyLevel = .steadiest
    private var config: SteadyConfig { SteadyConfig.preset(steady) ?? .unfiltered }

    var currentShape: GardenShape? { guide == nil || orderIndex >= order.count ? nil : order[orderIndex] }

    // MARK: Lifecycle

    func setUp(height: CGFloat, palette: GardenPalette, announce: @escaping (String) -> Void) {
        self.announce = announce
        if let engine, abs(engine.height - height) < 1, engine.palette.isBright == palette.isBright { return }
        if let engine { GardenStorage.save(engine) }
        let scale = min(2, UIScreen.main.scale)
        engine = GardenEngine(height: height, scale: scale, palette: palette)
        if let engine { GardenStorage.load(into: engine) }
        if pathMode { loadShape() }
        dirty = true
        publish()
    }

    func start() {
        guard link == nil else { return }
        proxy.onFrame = { [weak self] time in self?.step(time) }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
        lastTime = CACurrentMediaTime()
        if AppStore.shared.state.settings.ambience { SoundEngine.shared.setLoop(.wind, level: 0.22, fade: 1.5) }
    }

    func stop() {
        link?.invalidate()
        link = nil
        SoundEngine.shared.stopLoop(.sand, fade: 0.3)
        SoundEngine.shared.stopLoop(.wind, fade: 1)
        if let engine { GardenStorage.save(engine) }
    }

    // MARK: Modes

    func begin(tracing: Bool) {
        layer = .garden
        pathMode = tracing
        label = ""
        if tracing { order = GardenShape.allCases.shuffled(); orderIndex = 0; loadShape() } else { guide = nil }
        dirty = true
    }

    func togglePath() {
        pathMode.toggle()
        if pathMode {
            if guide == nil || orderIndex >= order.count { order = GardenShape.allCases.shuffled(); orderIndex = 0 }
            loadShape()
        } else {
            guide = nil
            setLabel("")
        }
        dirty = true
    }

    func nextPath() {
        orderIndex = (orderIndex + 1) % order.count
        loadShape()
        dirty = true
    }

    func finish() {
        clearStroke()
        SoundEngine.shared.setLoop(.sand, level: 0, fade: 0.3)
        layer = .rest
        if let engine { GardenStorage.save(engine) }
        announce("Rest well.")
    }

    func wake() {
        layer = .intro
        hinted = false
        pathMode = false
        guide = nil
        label = ""
    }

    private func loadShape() {
        guard let engine else { return }
        if orderIndex >= order.count {
            guide = nil
            setLabel("That’s all three. Smooth it away whenever you’re ready.")
            return
        }
        let shape = order[orderIndex]
        let fy = engine.height / 874
        guide = GardenShape.resample(shape.points().map { CGPoint(x: $0.x, y: $0.y * fy) })
        covered = [Bool](repeating: false, count: guide?.count ?? 0)
        coveredCount = 0
        maxCovered = 0
        doneAt = nil
        guideAlpha = 1
        tracePercent = 0
        setLabel(shape.name)
        announce("Trace the path: \(shape.name)")
    }

    private func setLabel(_ text: String) {
        label = text
        if !text.isEmpty { announce(text) }
    }

    // MARK: Input (design-space points)

    func touchDown(_ p: CGPoint) {
        if isDown { touchMoved(p); return }
        guard layer == .garden, sweepStart == nil, let engine else { return }
        let now = CACurrentMediaTime()
        isDown = true
        if let rock = engine.rock(at: p) {
            tap = (rock, p, now)
            return
        }
        beginStroke(at: p, time: now)
    }

    func touchMoved(_ p: CGPoint) {
        guard isDown else { return }
        if let t = tap {
            if hypot(p.x - t.at.x, p.y - t.at.y) > config.tapMove {
                tap = nil
                beginStroke(at: p, time: CACurrentMediaTime())
            }
            return
        }
        raw = p
    }

    func touchUp() {
        guard isDown else { return }
        isDown = false
        if let t = tap, CACurrentMediaTime() - t.time < config.tapTime { ripple(t.rock) }
        tap = nil
    }

    private func beginStroke(at p: CGPoint, time: Double) {
        filter = SteadyConfig.preset(steady).map { OneEuroFilter(config: $0) }
        raw = p
        let smoothed = filter?.filter(p, time: time) ?? p
        target = smoothed
        head = smoothed
        direction = nil
        previousTines = nil
    }

    private func clearStroke() {
        target = nil; raw = nil; previousTines = nil; head = nil; direction = nil; isDown = false; tap = nil
    }

    // MARK: One-tap raking (VoiceOver, Switch Control, motor access)

    func rakeLine() {
        guard let engine else { return }
        lineRow += 1
        autoRake(engine.lineAcross(row: lineRow))
        announce("Raked a line.")
    }

    func ripple(_ rock: GardenRock) {
        guard let engine else { return }
        engine.clearRockApron(rock)
        Haptics.shared.grain(0.5)
        if reduceMotion {
            engine.rake(along: engine.ringPoints(rock, from: 0, to: .pi * 2 + 0.1))
            dirty = true
        } else {
            ripples.removeAll { $0.rock === rock }
            ripples.append((rock, CACurrentMediaTime(), -.pi / 2))
        }
    }

    func rippleStone(_ index: Int) {
        guard let engine, engine.rocks.indices.contains(index) else { return }
        ripple(engine.rocks[index])
        announce("Rings raked around the stone.")
    }

    func traceNextPart() {
        guard let guide, doneAt == nil, !guide.isEmpty else { return }
        let from = maxCovered, to = min(guide.count - 1, from + Int(ceil(Double(guide.count) * 0.15)))
        autoRake(Array(guide[max(0, from - 1)...to])) { [weak self] in
            guard let self else { return }
            for i in from...to where !self.covered[i] { self.covered[i] = true; self.coveredCount += 1 }
            self.maxCovered = to
        }
    }

    private func autoRake(_ points: [CGPoint], done: (() -> Void)? = nil) {
        guard let engine else { return }
        if reduceMotion {
            engine.rake(along: points)
            done?()
            dirty = true
        } else {
            autoRakes.append((points, CACurrentMediaTime(), 0, done))
        }
    }

    func smooth() {
        clearStroke()
        sweepStart = CACurrentMediaTime()
        SoundEngine.shared.play(.sweep, volume: 0.8)
        setLabel("")
        announce("Smoothing the sand.")
    }

    // MARK: Frame loop

    private func step(_ now: CFTimeInterval) {
        guard let engine else { return }
        let dt = min(0.1, now - lastTime)
        lastTime = now
        let cfg = config

        if let r = raw, head != nil { target = filter?.filter(r, time: now) ?? r }

        if let tgt = target, var f = head {
            let dx = tgt.x - f.x, dy = tgt.y - f.y, d = hypot(dx, dy)
            let ease = 1 - pow(0.86, CGFloat(dt * 60))
            let maxStep = cfg.speed * CGFloat(dt)
            var mx = dx * ease, my = dy * ease
            let sp = hypot(mx, my)
            if sp > maxStep { mx *= maxStep / sp; my *= maxStep / sp }
            f.x += mx; f.y += my
            head = f
            let v = min(sp, maxStep)
            let vf = v / max(CGFloat(dt * 60), 0.01)
            if vf > 0.25 {
                let ux = mx / v, uy = my / v, k = min(1, v / cfg.turnLength)
                var dir = direction ?? CGVector(dx: ux, dy: uy)
                if direction != nil {
                    dir.dx += (ux - dir.dx) * k
                    dir.dy += (uy - dir.dy) * k
                    let n = max(hypot(dir.dx, dir.dy), 0.0001)
                    dir.dx /= n; dir.dy /= n
                }
                direction = dir
                let t = engine.tines(at: f, normal: CGVector(dx: -dir.dy, dy: dir.dx))
                if let prev = previousTines { engine.segment(from: prev, to: t, direction: dir) }
                previousTines = t
                travel += v
                if travel > 36 { travel = 0; Haptics.shared.grain(0.25) }
                activeSeconds += dt
                if !hinted { hinted = true }
                markCovered(near: f, radius: cfg.cover)
                dirty = true
            }
            if soundOn { SoundEngine.shared.setLoop(.sand, level: Float(min(0.7, vf * 0.11)), fade: 0.12) }
            let rawGap = raw.map { hypot($0.x - f.x, $0.y - f.y) } ?? 0
            if !isDown && d < 0.6 && rawGap < 0.6 {
                target = nil; raw = nil; previousTines = nil; head = nil
                SoundEngine.shared.setLoop(.sand, level: 0, fade: 0.3)
            }
        }

        if !pathMode && !nudged && activeSeconds > 180 && layer == .garden {
            nudged = true
            setLabel("Smooth it away whenever you’re ready.")
        }

        if pathMode, let g = guide, layer == .garden {
            if doneAt == nil {
                if Double(coveredCount) / Double(max(1, g.count)) >= 0.86 {
                    doneAt = now
                    setLabel("Lovely.")
                    Haptics.shared.success()
                    SoundEngine.shared.play(.bell, volume: 0.5)
                }
            } else if let done = doneAt {
                guideAlpha = max(0, 1 - (now - done) / 0.9)
                dirty = true
                if now - done > 2.2 { orderIndex += 1; loadShape() }
            }
            let pct = Int(min(1, Double(coveredCount) / Double(max(1, g.count)) / 0.86) * 100)
            if pct != tracePercent { tracePercent = pct }
        }

        for i in ripples.indices {
            let p = min(1, (now - ripples[i].start) / 1.6)
            let end = -.pi / 2 + CGFloat(p) * (.pi * 2 + 0.12)
            if end > ripples[i].angle {
                engine.rake(along: engine.ringPoints(ripples[i].rock, from: ripples[i].angle - 0.03, to: end))
                ripples[i].angle = end
                dirty = true
            }
        }
        ripples.removeAll { now - $0.start >= 1.6 }

        var finished: [Int] = []
        for i in autoRakes.indices {
            let item = autoRakes[i]
            let p = min(1, (now - item.start) / 1.4)
            let upto = Int(floor(p * Double(item.points.count - 1)))
            if upto > item.index {
                engine.rake(along: Array(item.points[max(0, item.index - 1)...upto]))
                autoRakes[i].index = upto
                dirty = true
            }
            if p >= 1 { finished.append(i) }
        }
        for i in finished.reversed() { autoRakes[i].done?(); autoRakes.remove(at: i) }

        if target == nil && soundOn {
            SoundEngine.shared.setLoop(.sand, level: (ripples.isEmpty && autoRakes.isEmpty) ? 0 : 0.4, fade: 0.25)
        }

        if let start = sweepStart {
            let p = min(1, (now - start) / (reduceMotion ? 0.01 : 2.4))
            let e = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            let y = CGFloat(e) * (engine.height + 26) - 10
            engine.clearTop(y)
            sweepY = y
            dirty = true
            if p >= 1 {
                sweepStart = nil
                sweepY = nil
                engine.clear()
                GardenStorage.eraseSaved(paletteBright: engine.palette.isBright)
                nudged = false
                activeSeconds = 0
                setLabel("Sand smoothed.")
                if pathMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                        guard let self, self.layer == .garden, self.sweepStart == nil, self.pathMode else { return }
                        self.order = GardenShape.allCases.shuffled()
                        self.orderIndex = 0
                        self.loadShape()
                        self.dirty = true
                    }
                }
            }
        }

        if head != nil { dirty = true }
        if dirty { publish() }
    }

    private func markCovered(near f: CGPoint, radius: CGFloat) {
        guard pathMode, let g = guide, doneAt == nil else { return }
        for i in g.indices where !covered[i] {
            let q = g[i]
            if abs(q.x - f.x) < radius && abs(q.y - f.y) < radius && hypot(q.x - f.x, q.y - f.y) < radius {
                covered[i] = true
                coveredCount += 1
                if i > maxCovered && i < maxCovered + 40 { maxCovered = i }
            }
        }
        while maxCovered < g.count - 1 && covered[maxCovered + 1] { maxCovered += 1 }
    }

    private func publish() {
        dirty = false
        ridge = engine?.ridgeImage()
        groove = engine?.grooveImage()
        frame &+= 1
    }

    // MARK: Accessibility

    var accessibilityDescription: String {
        var d = "Sand garden with three stones and a ginkgo leaf."
        if pathMode, let shape = currentShape { d += " Path: \(shape.name), \(tracePercent)% traced." }
        else if layer == .garden { d += " Raking freely." }
        return d
    }
}
