import CoreGraphics
import SwiftUI

// Port of drawably's rough renderer (dist/prng.js + dist/rough.js). The
// arithmetic matches the JS bit for bit, so a seed draws the same strokes here
// as it does on the web.

/// Seeded PRNG, identical to drawably's `mulberry32`.
public struct Mulberry32 {
    private var a: UInt32

    public init(_ seed: UInt32) { a = seed }

    public mutating func next() -> Double {
        a = a &+ 0x6d2b79f5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4294967296
    }
}

public func randomSeed() -> UInt32 { UInt32.random(in: .min ... .max) }

/// Options every rough shape takes. `boilSeed` picks one boil frame.
public struct RoughOptions: Hashable, Sendable {
    public var seed: UInt32
    public var roughness: Double
    public var boil: Double
    public var boilSeed: UInt32?

    public init(seed: UInt32, roughness: Double = 1, boil: Double = 0.3, boilSeed: UInt32? = nil) {
        self.seed = seed
        self.roughness = roughness
        self.boil = boil
        self.boilSeed = boilSeed
    }

    /// The options for boil frame `i` of a sketch, as `variants` builds them.
    public func frame(_ i: Int) -> RoughOptions {
        var o = self
        o.boilSeed = seed &+ UInt32(i + 1) &* 7919
        return o
    }

    func with(seed: UInt32) -> RoughOptions {
        var o = self
        o.seed = seed
        return o
    }
}

/// V8's `Math.hypot` (scaled, Kahan-compensated). It is not correctly rounded,
/// and a length landing exactly on a sampling step (a 12px arrow head, say)
/// must round the same way to sample the same number of points.
func jsHypot(_ a: Double, _ b: Double) -> Double {
    let m = max(abs(a), abs(b))
    if m == 0 { return 0 }
    var sum = 0.0, compensation = 0.0
    for v in [a, b] {
        let r = v / m
        let summand = r * r - compensation
        let preliminary = sum + summand
        compensation = (preliminary - sum) - summand
        sum = preliminary
    }
    return sum.squareRoot() * m
}

public enum Rough {
    static func sampleLine(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, step: Double = 8) -> [CGPoint] {
        let n = max(2, Int((jsHypot(x2 - x1, y2 - y1) / step).rounded(.up)))
        return (0...n).map { i in
            CGPoint(x: x1 + (x2 - x1) * Double(i) / Double(n), y: y1 + (y2 - y1) * Double(i) / Double(n))
        }
    }

    static func ellipsePoints(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ a0: Double, _ a1: Double, _ n: Int) -> [CGPoint] {
        (0...n).map { i in
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    static func arcPoints(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double, _ n: Int = 4) -> [CGPoint] {
        ellipsePoints(cx, cy, r, r, a0, a1, n)
    }

    static func roundedRectPoints(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> [CGPoint] {
        let r = min(r, w / 2, h / 2)
        return sampleLine(x + r, y, x + w - r, y)
            + arcPoints(x + w - r, y + r, r, -.pi / 2, 0)
            + sampleLine(x + w, y + r, x + w, y + h - r)
            + arcPoints(x + w - r, y + h - r, r, 0, .pi / 2)
            + sampleLine(x + w - r, y + h, x + r, y + h)
            + arcPoints(x + r, y + h - r, r, .pi / 2, .pi)
            + sampleLine(x, y + h - r, x, y + r)
            + arcPoints(x + r, y + r, r, .pi, .pi * 1.5)
    }

    static func jitter(_ points: [CGPoint], _ rand: inout Mulberry32, _ amp: Double) -> [CGPoint] {
        points.map { p in
            let dx = (rand.next() * 2 - 1) * amp
            let dy = (rand.next() * 2 - 1) * amp
            return CGPoint(x: p.x + dx, y: p.y + dy)
        }
    }

    /// Quadratic curves through the midpoints, like drawably's `toPath`.
    static func append(_ points: [CGPoint], to path: inout Path, close: Bool) {
        guard let first = points.first else { return }
        path.move(to: first)
        if points.count > 2 {
            for i in 1..<(points.count - 1) {
                let c = points[i], n = points[i + 1]
                path.addQuadCurve(to: CGPoint(x: (c.x + n.x) / 2, y: (c.y + n.y) / 2), control: c)
            }
        }
        path.addLine(to: points[points.count - 1])
        if close { path.closeSubpath() }
    }

    static func boilPass(_ points: [CGPoint], _ o: RoughOptions) -> [CGPoint] {
        guard o.boil != 0, let bs = o.boilSeed else { return points }
        var r = Mulberry32(bs)
        return jitter(points, &r, o.boil)
    }

    static func doubleStroke(_ points: [CGPoint], _ o: RoughOptions, close: Bool) -> Path {
        var rand = Mulberry32(o.seed)
        let amp = 1.5 * o.roughness
        var path = Path()
        append(boilPass(jitter(points, &rand, amp), o), to: &path, close: close)
        append(boilPass(jitter(points, &rand, amp * 1.4), o), to: &path, close: close)
        return path
    }

    public static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ o: RoughOptions) -> Path {
        doubleStroke(sampleLine(x1, y1, x2, y2), o, close: false)
    }

    public static func circle(_ cx: Double, _ cy: Double, _ r: Double, _ o: RoughOptions) -> Path {
        ellipse(cx, cy, r, r, o)
    }

    public static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ o: RoughOptions) -> Path {
        // Ramanujan's perimeter approximation, sampled every 8px like the lines
        let h = pow((rx - ry) / (rx + ry), 2)
        let perimeter = Double.pi * (rx + ry) * (1 + (3 * h) / (10 + (4 - 3 * h).squareRoot()))
        let n = max(8, Int((perimeter / 8).rounded(.up)))
        return doubleStroke(Array(ellipsePoints(cx, cy, rx, ry, 0, .pi * 2, n).dropLast()), o, close: true)
    }

    static let arrowHead = 12.0
    static let arrowHeadAngle = Double.pi / 6

    public static func arrow(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ o: RoughOptions) -> Path {
        let a = atan2(y2 - y1, x2 - x1)
        func wing(_ da: Double) -> (Double, Double) {
            (x2 - arrowHead * cos(a + da), y2 - arrowHead * sin(a + da))
        }
        let (lx, ly) = wing(arrowHeadAngle)
        let (rx, ry) = wing(-arrowHeadAngle)
        var rand = Mulberry32(o.seed)
        let amp = 1.2 * o.roughness
        var path = line(x1, y1, x2, y2, o)
        for (px, py) in [(lx, ly), (rx, ry)] {
            append(boilPass(jitter(sampleLine(x2, y2, px, py, step: 4), &rand, amp), o), to: &path, close: false)
        }
        return path
    }

    public static func roundedRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ o: RoughOptions) -> Path {
        doubleStroke(roundedRectPoints(x, y, w, h, r), o, close: true)
    }

    public static func checkmark(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ o: RoughOptions) -> Path {
        var rand = Mulberry32(o.seed)
        // duplicate vertex keeps the corner sharp under midpoint smoothing
        let pts = sampleLine(x, y + h * 0.6, x + w * 0.35, y + h, step: 4)
            + sampleLine(x + w * 0.35, y + h, x + w, y, step: 4)
        var path = Path()
        append(boilPass(jitter(pts, &rand, 1.2 * o.roughness), o), to: &path, close: false)
        return path
    }

    public static func scribbleFill(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ o: RoughOptions) -> Path {
        var rand = Mulberry32(o.seed)
        let gap = 6.0
        var pts: [CGPoint] = []
        var flip = false
        var t = gap
        while t < w + h {
            let a = CGPoint(x: x + max(0, t - h), y: y + min(t, h))
            let b = CGPoint(x: x + min(t, w), y: y + max(0, t - w))
            pts += flip ? [b, a] : [a, b]
            flip.toggle()
            t += gap
        }
        var path = Path()
        guard pts.count >= 2 else { return path }
        append(boilPass(jitter(pts, &rand, 1.2 * o.roughness), o), to: &path, close: false)
        return path
    }

    /// The boil frames of a shape: `n` micro-wobbled copies of one base sketch.
    public static func variants(_ o: RoughOptions, count n: Int = 3, _ gen: (RoughOptions) -> Path) -> [Path] {
        (0..<n).map { gen(o.frame($0)) }
    }
}
