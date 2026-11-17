import CoreGraphics
import SwiftUI
import UIKit

// MARK: - Palette

struct GardenPalette {
    var sand: UIColor
    var sandLo: UIColor
    var ridge: UIColor
    var groove: UIColor
    var rock: Color
    var rockShade: Color
    var cast: Color
    var contour: Color
    var rim: Color
    var shadow: Color
    var leaf: Color
    var leafLine: Color
    var guide: Color
    var edge: Color
    var head: Color
    var grain: (r: Double, g: Double, b: Double)
    var grainAlpha: Double
    var isBright: Bool

    static let night = GardenPalette(
        sand: UIColor(Color(hex: 0x3A3E5A)), sandLo: UIColor(Color(hex: 0x30344E)),
        ridge: UIColor(Color(hex: 0x595A6E)), groove: UIColor(Color(hex: 0x23273B)),
        rock: Color(hex: 0x6E768F), rockShade: Color(hex: 0x4A5068),
        cast: Color(hex: 0x141726, opacity: 0.45), contour: Color(hex: 0xFBEDD6, opacity: 0.2),
        rim: Color(hex: 0xE8F3FE, opacity: 0.45), shadow: Color(hex: 0x080912, opacity: 0.5),
        leaf: Color(hex: 0xF6CE87), leafLine: Color(hex: 0xC9A262), guide: Color(hex: 0xFBEDD6, opacity: 0.55),
        edge: Color(hex: 0xFBEDD6, opacity: 0.55), head: Color(hex: 0xFBEDD6, opacity: 0.5),
        grain: (251, 237, 214), grainAlpha: 0.045, isBright: false)

    static let bright = GardenPalette(
        sand: UIColor(Color(hex: 0xC1B8B1)), sandLo: UIColor(Color(hex: 0xB2AAA7)),
        ridge: UIColor(Color(hex: 0xE2D6C6)), groove: UIColor(Color(hex: 0x979296)),
        rock: Color(hex: 0x9AA3B7), rockShade: Color(hex: 0x7A8399),
        cast: Color(hex: 0x1C2139, opacity: 0.22), contour: Color(hex: 0xFBEDD6, opacity: 0.4),
        rim: Color(hex: 0xFBEDD6, opacity: 0.7), shadow: Color(hex: 0x1C2139, opacity: 0.28),
        leaf: Color(hex: 0xF6CE87), leafLine: Color(hex: 0xB98E4C), guide: Color(hex: 0x1C2139, opacity: 0.85),
        edge: Color(hex: 0x1C2139, opacity: 0.7), head: Color(hex: 0x1C2139, opacity: 0.45),
        grain: (28, 33, 57), grainAlpha: 0.06, isBright: true)
}

// MARK: - Random (mulberry32, same as the web prototype)

struct SeededRandom {
    private var state: UInt32
    init(seed: UInt32) { state = seed }
    mutating func next() -> CGFloat {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (1 | t)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return CGFloat(t ^ (t >> 14)) / 4_294_967_296
    }
}

// MARK: - Stones and leaf

final class GardenRock {
    let x: CGFloat, y: CGFloat, r: CGFloat, sx: CGFloat, sy: CGFloat
    private let amps: [CGFloat]
    private let phases: [CGFloat]
    private(set) var outer: [CGPoint] = []
    private(set) var contours: [[CGPoint]] = []

    init(x: CGFloat, y: CGFloat, r: CGFloat, sx: CGFloat, sy: CGFloat, seed: UInt32) {
        self.x = x; self.y = y; self.r = r; self.sx = sx; self.sy = sy
        var rng = SeededRandom(seed: seed)
        amps = [0.07 + rng.next() * 0.03, 0.04 + rng.next() * 0.03, 0.015 + rng.next() * 0.015]
        phases = [rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3]
        outer = ring(scale: 1, offset: .zero, phase: 0)
        let peak = CGPoint(x: r * 0.14, y: -r * 0.18)
        contours = [0.78, 0.57, 0.38, 0.2].enumerated().map { i, level in
            ring(scale: level, offset: CGPoint(x: peak.x * (1 - level), y: peak.y * (1 - level)),
                 phase: CGFloat(i + 1) * 0.35 * (rng.next() - 0.5))
        }
    }

    func rad(_ t: CGFloat) -> CGFloat {
        r * (1 + amps[0] * sin(2 * t + phases[0]) + amps[1] * sin(3 * t + phases[1]) + amps[2] * sin(5 * t + phases[2]))
    }

    private func ring(scale: CGFloat, offset: CGPoint, phase: CGFloat) -> [CGPoint] {
        (0..<72).map { i in
            let t = CGFloat(i) / 72 * .pi * 2
            let rr = rad(t + phase) * scale
            return CGPoint(x: x + offset.x + cos(t) * rr * sx, y: y + offset.y + sin(t) * rr * sy)
        }
    }

    func contains(_ p: CGPoint, pad: CGFloat) -> Bool {
        let dx = (p.x - x) / sx, dy = (p.y - y) / sy
        return hypot(dx, dy) < rad(atan2(dy, dx)) + pad
    }

    func blobPath(grow: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0...72 {
            let t = CGFloat(i) / 72 * .pi * 2
            let rr = rad(t) + grow
            let p = CGPoint(x: x + cos(t) * rr * sx, y: y + sin(t) * rr * sy)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

struct GardenLeaf { var x: CGFloat; var y: CGFloat; var r: CGFloat; var angle: CGFloat }

// MARK: - Trace paths

enum GardenShape: String, CaseIterable {
    case ginkgo, river, spiral
    var name: String {
        switch self {
        case .ginkgo: return "Ginkgo leaf"
        case .river: return "Winding river"
        case .spiral: return "Spiral"
        }
    }

    /// Points in the 402 × 874 design space.
    func points() -> [CGPoint] {
        switch self {
        case .ginkgo:
            let ax: CGFloat = 201, ay: CGFloat = 572, R: CGFloat = 168
            func P(_ deg: CGFloat) -> CGPoint {
                let a = deg * .pi / 180
                let r = R - 16 * exp(-pow((deg - 90) / 9, 2))
                return CGPoint(x: ax + cos(a) * r, y: ay - sin(a) * r)
            }
            var pts = GardenShape.quad(CGPoint(x: ax, y: 700), CGPoint(x: ax - 6, y: 640), CGPoint(x: ax, y: ay), n: 24)
            pts += GardenShape.quad(CGPoint(x: ax, y: ay), CGPoint(x: 126, y: 580), P(158))
            var d: CGFloat = 158
            while d >= 22 { pts.append(P(d)); d -= 1 }
            pts += GardenShape.quad(P(22), CGPoint(x: 276, y: 580), CGPoint(x: ax, y: ay))
            return pts
        case .river:
            return (0...260).map { i in
                let t = CGFloat(i) / 260
                return CGPoint(x: 201 + 125 * sin(.pi * 2 * t + 0.2), y: 140 + t * 650)
            }
        case .spiral:
            return (0...600).map { i in
                let t = CGFloat(i) / 600, a = -.pi / 2 + t * 3 * .pi * 2, r = 156 - 138 * t
                return CGPoint(x: 201 + cos(a) * r, y: 452 + sin(a) * r)
            }
        }
    }

    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, n: Int = 40) -> [CGPoint] {
        (0...n).map { i in
            let t = CGFloat(i) / CGFloat(n), u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
        }
    }

    static func resample(_ pts: [CGPoint], step: CGFloat = 4) -> [CGPoint] {
        guard var last = pts.first else { return [] }
        var out = [last]
        var carry: CGFloat = 0
        for next in pts.dropFirst() {
            var d = hypot(next.x - last.x, next.y - last.y)
            while carry + d >= step && d > 0 {
                let t = (step - carry) / d
                last = CGPoint(x: last.x + (next.x - last.x) * t, y: last.y + (next.y - last.y) * t)
                out.append(last)
                d = hypot(next.x - last.x, next.y - last.y)
                carry = 0
            }
            carry += d
            last = next
        }
        return out
    }
}

// MARK: - Engine

/// Draws raked grooves into two bitmap layers (light ridges and dark grooves), like the web prototype.
/// Coordinates are in a 402-point-wide design space; the height follows the screen.
final class GardenEngine {
    let width: CGFloat = 402
    let height: CGFloat
    let scale: CGFloat
    let rocks: [GardenRock]
    let leaf: GardenLeaf
    private(set) var palette: GardenPalette
    private(set) var base: CGImage?
    private let ridge: CGContext
    private let groove: CGContext
    let tines = 5
    let space: CGFloat = 9
    let ringGap: CGFloat = 30

    var pixelWidth: Int { ridge.width }
    var pixelHeight: Int { ridge.height }

    init?(height: CGFloat, scale: CGFloat, palette: GardenPalette) {
        self.height = height
        self.scale = scale
        self.palette = palette
        let fy = height / 874
        rocks = [
            GardenRock(x: 104, y: 246 * fy, r: 48, sx: 1.18, sy: 0.94, seed: 3),
            GardenRock(x: 312, y: 626 * fy, r: 30, sx: 1.1, sy: 0.95, seed: 8),
            GardenRock(x: 266, y: 690 * fy, r: 17, sx: 1.15, sy: 0.92, seed: 13),
        ]
        leaf = GardenLeaf(x: 322, y: 178 * fy, r: 15, angle: -0.55)
        let w = Int((402 * scale).rounded()), h = Int((height * scale).rounded())
        guard let r = GardenEngine.makeLayer(w: w, h: h, scale: scale),
              let g = GardenEngine.makeLayer(w: w, h: h, scale: scale) else { return nil }
        ridge = r
        groove = g
        base = GardenEngine.makeBase(w: w, h: h, palette: palette)
    }

    private static func makeLayer(w: Int, h: Int, scale: CGFloat) -> CGContext? {
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setShouldAntialias(true)
        return ctx
    }

    /// Sand: a soft radial gradient with fine grain.
    private static func makeBase(w: Int, h: Int, palette p: GardenPalette) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [p.sand.cgColor, p.sandLo.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            let W = CGFloat(w), H = CGFloat(h)
            // CG's origin is bottom-left; the light comes from the top right.
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: W * 0.8, y: H), startRadius: 10,
                                   endCenter: CGPoint(x: W * 0.6, y: H * 0.7), endRadius: H * 1.05,
                                   options: [.drawsAfterEndLocation])
        }
        if let data = ctx.data {
            let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            var rng = SeededRandom(seed: 7)
            let count = w * h / 20
            func speck(_ r: Double, _ g: Double, _ b: Double, _ a: Double) {
                let i = Int(rng.next() * CGFloat(w * h - 1)) * 4
                px[i] = UInt8(min(255, Double(px[i]) * (1 - a) + r * a))
                px[i + 1] = UInt8(min(255, Double(px[i + 1]) * (1 - a) + g * a))
                px[i + 2] = UInt8(min(255, Double(px[i + 2]) * (1 - a) + b * a))
            }
            for _ in 0..<count { speck(p.grain.r, p.grain.g, p.grain.b, Double(rng.next()) * p.grainAlpha * 1.6) }
            for _ in 0..<(count / 3) { speck(0, 0, 0, Double(rng.next()) * p.grainAlpha * 1.6) }
        }
        return ctx.makeImage()
    }

    func setPalette(_ new: GardenPalette) {
        palette = new
        base = GardenEngine.makeBase(w: pixelWidth, h: pixelHeight, palette: new)
        clear()
    }

    // MARK: Layers

    func ridgeImage() -> CGImage? { ridge.makeImage() }
    func grooveImage() -> CGImage? { groove.makeImage() }

    func clear() { clearTop(height + 30) }

    /// Clears everything above `y` (used by the smoothing sweep).
    func clearTop(_ y: CGFloat) {
        for ctx in [ridge, groove] {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fill(CGRect(x: -10, y: -40, width: width + 20, height: max(0, y + 40)))
            ctx.restoreGState()
        }
    }

    func clearRockApron(_ rock: GardenRock) {
        for ctx in [ridge, groove] {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(rock.blobPath(grow: 12))
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    func inRock(_ p: CGPoint, pad: CGFloat = 5) -> Bool { rocks.contains { $0.contains(p, pad: pad) } }

    func rock(at p: CGPoint) -> GardenRock? { rocks.first { $0.contains(p, pad: 8) } }

    func tines(at p: CGPoint, normal n: CGVector, count: Int? = nil) -> [CGPoint] {
        let c = count ?? tines
        let mid = CGFloat(c - 1) / 2
        return (0..<c).map { i in
            let o = (CGFloat(i) - mid) * space
            return CGPoint(x: p.x + n.dx * o, y: p.y + n.dy * o)
        }
    }

    /// Rakes one step between two rows of tine points.
    func segment(from a: [CGPoint], to b: [CGPoint], direction dir: CGVector? = nil) {
        guard a.count == b.count, !a.isEmpty else { return }
        let last = a.count - 1
        var lo = 0, hi = last
        if let dir {
            let forward = a.indices.map { i in (b[i].x - a[i].x) * dir.dx + (b[i].y - a[i].y) * dir.dy > -0.05 }
            guard let first = forward.firstIndex(of: true), let end = forward.lastIndex(of: true) else { return }
            lo = first; hi = end
            for i in lo...hi where !forward[i] {
                if i - lo < hi - i { lo = i + 1 } else { hi = i - 1 }
            }
            if lo > hi { return }
        }
        // Erase what was under this step so crossing lines look raked over.
        func unit(_ p: CGPoint, _ q: CGPoint) -> CGVector {
            let l = max(hypot(q.x - p.x, q.y - p.y), 0.0001)
            return CGVector(dx: (q.x - p.x) / l, dy: (q.y - p.y) / l)
        }
        let e = unit(a[lo], a[hi]), f = unit(b[lo], b[hi])
        let pad: CGFloat = 4.2
        let eraser = CGMutablePath()
        eraser.move(to: CGPoint(x: a[lo].x - e.dx * pad, y: a[lo].y - e.dy * pad))
        eraser.addLine(to: CGPoint(x: a[hi].x + e.dx * pad, y: a[hi].y + e.dy * pad))
        eraser.addLine(to: CGPoint(x: b[hi].x + f.dx * pad, y: b[hi].y + f.dy * pad))
        eraser.addLine(to: CGPoint(x: b[lo].x - f.dx * pad, y: b[lo].y - f.dy * pad))
        eraser.closeSubpath()
        for ctx in [ridge, groove] {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(eraser)
            ctx.fillPath()
            ctx.restoreGState()
        }

        var ok = [Bool](repeating: false, count: a.count)
        for i in lo...hi { ok[i] = !(inRock(a[i]) || inRock(b[i])) }

        let ridgePath = CGMutablePath(), groovePath = CGMutablePath()
        for i in 0...last where ok[i] {
            ridgePath.move(to: CGPoint(x: a[i].x - 0.8, y: a[i].y - 0.8))
            ridgePath.addLine(to: CGPoint(x: b[i].x - 0.8, y: b[i].y - 0.8))
            groovePath.move(to: CGPoint(x: a[i].x + 0.5, y: a[i].y + 0.5))
            groovePath.addLine(to: CGPoint(x: b[i].x + 0.5, y: b[i].y + 0.5))
        }
        ridge.setStrokeColor(palette.ridge.cgColor)
        ridge.setLineWidth(6.8)
        ridge.addPath(ridgePath)
        ridge.strokePath()
        groove.setStrokeColor(palette.groove.cgColor)
        groove.setLineWidth(3.2)
        groove.addPath(groovePath)
        groove.strokePath()
    }

    /// Rakes along a path of points (used by rings, one-tap raking and tracing help).
    func rake(along pts: [CGPoint], count: Int? = nil) {
        var prev: [CGPoint]?
        for i in pts.indices {
            let a = pts[max(0, i - 1)], b = pts[min(pts.count - 1, i + 1)]
            let l = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
            let dx = (b.x - a.x) / l, dy = (b.y - a.y) / l
            let t = tines(at: pts[i], normal: CGVector(dx: -dy, dy: dx), count: count)
            if let prev { segment(from: prev, to: t) }
            prev = t
        }
    }

    func ringPoints(_ rock: GardenRock, from a0: CGFloat, to a1: CGFloat) -> [CGPoint] {
        let n = max(2, Int(ceil((a1 - a0) / 0.05)))
        return (0...n).map { i in
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)
            let rr = rock.rad(a)
            return CGPoint(x: rock.x + cos(a) * (rr * rock.sx + ringGap), y: rock.y + sin(a) * (rr * rock.sy + ringGap))
        }
    }

    func lineAcross(row: Int) -> [CGPoint] {
        let y = 30 + CGFloat((row * 53) % max(1, Int(height) - 34))
        return stride(from: CGFloat(-10), through: 412, by: 5).map { x in
            CGPoint(x: x, y: y + sin(x / 70 + y * 0.01) * 2.2)
        }
    }

    // MARK: Saving the garden between visits

    func restore(ridge ridgeImage: CGImage, groove grooveImage: CGImage) {
        guard ridgeImage.width == pixelWidth, ridgeImage.height == pixelHeight,
              grooveImage.width == pixelWidth, grooveImage.height == pixelHeight else { return }
        for (ctx, image) in [(ridge, ridgeImage), (groove, grooveImage)] {
            ctx.saveGState()
            ctx.concatenate(ctx.ctm.inverted())
            ctx.setBlendMode(.copy)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            ctx.restoreGState()
        }
    }
}

/// Keeps the last garden on this phone so it's still there next time.
enum GardenStorage {
    private static var folder: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("garden", isDirectory: true)
    }

    static func save(_ engine: GardenEngine) {
        guard let folder, let ridge = engine.ridgeImage(), let groove = engine.grooveImage() else { return }
        let palette = engine.palette.isBright ? "bright" : "night"
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let r = UIImage(cgImage: ridge).pngData(), let g = UIImage(cgImage: groove).pngData() {
                try? r.write(to: folder.appendingPathComponent("ridge-\(palette).png"), options: .atomic)
                try? g.write(to: folder.appendingPathComponent("groove-\(palette).png"), options: .atomic)
            }
        }
    }

    static func load(into engine: GardenEngine) {
        guard let folder else { return }
        let palette = engine.palette.isBright ? "bright" : "night"
        guard let r = UIImage(contentsOfFile: folder.appendingPathComponent("ridge-\(palette).png").path)?.cgImage,
              let g = UIImage(contentsOfFile: folder.appendingPathComponent("groove-\(palette).png").path)?.cgImage else { return }
        engine.restore(ridge: r, groove: g)
    }

    static func eraseSaved(paletteBright: Bool) {
        guard let folder else { return }
        let palette = paletteBright ? "bright" : "night"
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("ridge-\(palette).png"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("groove-\(palette).png"))
    }

    static func erase() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
