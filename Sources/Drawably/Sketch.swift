import SwiftUI

// The SwiftUI equivalent of drawably's `paint` + boil CSS: each layer is a
// shape generated from the view's size, and three micro-wobbled frames of it
// are cycled on one shared clock (1200ms; 450ms while a button loads).

public typealias RoughGen = @Sendable (CGSize, RoughOptions) -> Path

/// Inset of control outlines from the element's box.
let INSET = 3.0

/// A rough path generated for whatever rect it is laid out in.
public struct RoughShape: Shape {
    public var options: RoughOptions
    public var gen: RoughGen

    public init(_ options: RoughOptions, _ gen: @escaping RoughGen) {
        self.options = options
        self.gen = gen
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        return gen(rect.size, options).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// A schedule aligned to absolute time, so every sketch on screen steps its
/// boil frame together, like the single CSS frame counter.
struct BoilSchedule: TimelineSchedule {
    let step: TimeInterval

    func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var t = (start.timeIntervalSinceReferenceDate / step).rounded(.down) * step
        return AnyIterator {
            defer { t += step }
            return Date(timeIntervalSinceReferenceDate: t)
        }
    }
}

/// Hands its content the current boil frame index (0, 1 or 2), stepped on one
/// clock shared by every sketch on screen. Frozen at 0 without boil or with
/// Reduce Motion on.
public struct BoilClock<Content: View>: View {
    var active: Bool
    var cycle: TimeInterval
    var content: (Int) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(active: Bool = true, cycle: TimeInterval = 1.2, @ViewBuilder content: @escaping (Int) -> Content) {
        self.active = active
        self.cycle = cycle
        self.content = content
    }

    public var body: some View {
        if !active || reduceMotion {
            content(0)
        } else {
            let step = cycle / 3
            TimelineView(BoilSchedule(step: step)) { ctx in
                content(Int((ctx.date.timeIntervalSinceReferenceDate / step).rounded(.down)) % 3)
            }
        }
    }
}

/// Hands its content the options for the current boil frame.
public struct Boiling<Content: View>: View {
    var options: RoughOptions
    var cycle: TimeInterval
    var content: (RoughOptions) -> Content

    /// - Parameters:
    ///   - options: the sketch's seed, roughness and boil.
    ///   - cycle: one full pass through the three frames.
    public init(_ options: RoughOptions, cycle: TimeInterval = 1.2, @ViewBuilder content: @escaping (RoughOptions) -> Content) {
        self.options = options
        self.cycle = cycle
        self.content = content
    }

    public var body: some View {
        BoilClock(active: options.boil != 0, cycle: cycle) { i in content(options.frame(i)) }
    }
}

extension Shape {
    /// drawably's pen: round caps and joins.
    func pen(_ color: Color, _ width: CGFloat) -> some View {
        stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// The `.drawably-blob` layer: filled and outlined 4px wide.
    func blob(_ color: Color) -> some View {
        fill(color).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Shared geometry

enum Gen {
    static func outlineRect(_ r: Double) -> RoughGen {
        { s, o in Rough.roundedRect(INSET, INSET, s.width - 2 * INSET, s.height - 2 * INSET, r, o) }
    }

    static func focusRect(_ r: Double) -> RoughGen {
        { s, o in Rough.roundedRect(-1, -1, s.width + 2, s.height + 2, r, o) }
    }
}

// MARK: - Theme resolution

extension DrawablyTheme {
    func options(seed: UInt32, roughnessScale: Double = 1) -> RoughOptions {
        RoughOptions(seed: seed, roughness: roughness * roughnessScale, boil: boil)
    }
}

struct Ink {
    var stroke: Color
    var fill: Color
}

extension EnvironmentValues {
    var ink: Ink {
        if let drawablyInk { return Ink(stroke: drawablyInk, fill: drawablyInk) }
        return Ink(stroke: drawablyTheme.stroke, fill: drawablyTheme.fill)
    }
}

// MARK: - Interaction

/// Keeps a sketch's seed and re-sketches it on hover, the way drawably does on
/// `pointerenter`. Press re-sketching goes through `PressReportingStyle`.
struct Resketch: ViewModifier {
    @Binding var seed: UInt32
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside, enabled, !reduceMotion { seed = randomSeed() }
        }
    }
}

/// A plain button style that reports presses (drawably's `pointerdown` re-sketch).
struct PressReportingStyle: ButtonStyle {
    var onPress: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in onPress(pressed) }
    }
}

extension View {
    func resketch(_ seed: Binding<UInt32>, enabled: Bool = true) -> some View {
        modifier(Resketch(seed: seed, enabled: enabled))
    }
}

/// drawably's `--drawably-ease`.
extension Animation {
    static func drawablyEase(_ duration: TimeInterval) -> Animation {
        .timingCurve(0.2, 0, 0, 1, duration: duration)
    }

    /// CSS `ease`.
    static func cssEase(_ duration: TimeInterval) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: duration)
    }
}

/// An animation that `prefers-reduced-motion` switches off.
struct Motion<V: Equatable>: ViewModifier {
    var animation: Animation
    var value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(Motion(animation: animation, value: value))
    }
}
