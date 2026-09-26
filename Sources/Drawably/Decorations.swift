import SwiftUI

// Text decoration: annotate copy the way you would with a pen. Use the view
// modifiers on a word or short phrase, or mark runs inside a paragraph with
// `Text.drawably(_:)` and render it with `DrawablyText`, which draws one
// decoration per line a mark wraps onto.

public enum DrawablyMarkKind: Hashable, Sendable {
    /// A rough line under the text, re-sketched on hover.
    case underline
    /// A marker wash behind the text: fill colour at 30%, multiplied.
    case highlight
    /// A hand-drawn ellipse looping around the text, re-sketched on hover.
    case circle

    var interactive: Bool { self != .highlight }
}

// underline sits just under the text box; circle overshoots it the way a hand
// loops around a word rather than tracing its edges (tuned on 16–48px Inter)
private let UNDERLINE_GAP = 2.0
private let CIRCLE_PAD_X = 1.15
private let CIRCLE_PAD_Y = 1.4
private let CIRCLE_PAD = 4.0

extension DrawablyMarkKind {
    func path(_ s: CGSize, _ o: RoughOptions) -> Path {
        switch self {
        case .underline:
            Rough.line(0, s.height + UNDERLINE_GAP, s.width, s.height + UNDERLINE_GAP, o)
        case .highlight:
            Rough.scribbleFill(0, 0, s.width, s.height, o)
        case .circle:
            Rough.ellipse(s.width / 2, s.height / 2, (s.width / 2) * CIRCLE_PAD_X + CIRCLE_PAD, (s.height / 2) * CIRCLE_PAD_Y + CIRCLE_PAD, o)
        }
    }
}

// MARK: - View modifiers

struct DecorationModifier: ViewModifier {
    var kind: DrawablyMarkKind
    @State var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    func body(content: Content) -> some View {
        content
            .background {
                Boiling(theme.options(seed: seed)) { o in
                    let shape = RoughShape(o) { [kind] s, o in kind.path(s, o) }
                    if kind == .highlight {
                        // stroke as wide as the scribble gap so the hatching reads as one swipe
                        shape.pen(ink.fill.opacity(0.3), 6).blendMode(.multiply)
                    } else {
                        // on body copy the 2pt control stroke reads heavy
                        shape.pen(ink.stroke, theme.width ?? 1.5)
                    }
                }
                .accessibilityHidden(true)
            }
            .resketch($seed, enabled: kind.interactive)
    }
}

public extension View {
    /// A rough line under this view, re-sketched on hover.
    func drawablyUnderline(seed: UInt32? = nil) -> some View {
        modifier(DecorationModifier(kind: .underline, seed: seed ?? randomSeed()))
    }

    /// A marker wash behind this view.
    func drawablyHighlight(seed: UInt32? = nil) -> some View {
        modifier(DecorationModifier(kind: .highlight, seed: seed ?? randomSeed()))
    }

    /// A hand-drawn ellipse looping around this view, re-sketched on hover.
    func drawablyCircle(seed: UInt32? = nil) -> some View {
        modifier(DecorationModifier(kind: .circle, seed: seed ?? randomSeed()))
    }
}

// MARK: - Inline marks

/// Marks a run of text for `DrawablyText` to decorate.
public struct DrawablyMark: TextAttribute {
    public var kind: DrawablyMarkKind
    var id: String
}

public extension Text {
    /// Decorate this run when it is rendered inside `DrawablyText`. Runs are told
    /// apart by call site, so two marks never merge into one.
    func drawably(_ kind: DrawablyMarkKind, fileID: String = #fileID, line: Int = #line, column: Int = #column) -> Text {
        customAttribute(DrawablyMark(kind: kind, id: "\(fileID):\(line):\(column)"))
    }
}

/// Renders a `Text` with its `.drawably(_:)` runs decorated. A mark that wraps
/// gets one drawing per line. Hovering the text re-sketches its underlines and circles.
public struct DrawablyText: View {
    var text: Text
    @State private var seed: UInt32
    @State private var stillSeed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    public init(_ text: Text, seed: UInt32? = nil) {
        self.text = text
        _seed = State(initialValue: seed ?? randomSeed())
        _stillSeed = State(initialValue: seed.map { $0 &+ 1 } ?? randomSeed())
    }

    public var body: some View {
        BoilClock(active: theme.boil != 0) { frame in
            text.textRenderer(MarkRenderer(
                seed: seed, stillSeed: stillSeed, frame: frame,
                roughness: theme.roughness, boil: theme.boil,
                stroke: ink.stroke, fill: ink.fill, width: theme.width ?? 1.5
            ))
        }
        .resketch($seed)
    }
}

struct MarkRenderer: TextRenderer {
    var seed: UInt32
    var stillSeed: UInt32
    var frame: Int
    var roughness: Double
    var boil: Double
    var stroke: Color
    var fill: Color
    var width: CGFloat

    // a circle loops well outside the glyphs
    var displayPadding: EdgeInsets { EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32) }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        var marks: [String] = []
        var boxes: [(mark: DrawablyMark, rect: CGRect)] = []

        for line in layout {
            var current: (mark: DrawablyMark, rect: CGRect)?
            func flush() {
                if let c = current { boxes.append(c) }
                current = nil
            }
            for run in line {
                guard let mark = run[DrawablyMark.self] else { flush(); continue }
                let rect = run.typographicBounds.rect
                if let c = current, c.mark.id == mark.id {
                    current = (mark, c.rect.union(rect))
                } else {
                    flush()
                    current = (mark, rect)
                    if !marks.contains(mark.id) { marks.append(mark.id) }
                }
            }
            flush()
        }

        // decorations go under the glyphs, like the SVG layered beneath
        var linesSoFar: [String: UInt32] = [:]
        for box in boxes {
            let m = UInt32(marks.firstIndex(of: box.mark.id) ?? 0)
            let k = linesSoFar[box.mark.id, default: 0]
            linesSoFar[box.mark.id] = k + 1
            let base = box.mark.kind.interactive ? seed : stillSeed
            let o = RoughOptions(seed: base &+ m &* 104_729 &+ k, roughness: roughness, boil: boil).frame(frame)
            let path = box.mark.kind.path(box.rect.size, o).offsetBy(dx: box.rect.minX, dy: box.rect.minY)
            let style = StrokeStyle(lineWidth: box.mark.kind == .highlight ? 6 : width, lineCap: .round, lineJoin: .round)
            if box.mark.kind == .highlight {
                var wash = ctx
                wash.blendMode = .multiply
                wash.stroke(path, with: .color(fill.opacity(0.3)), style: style)
            } else {
                ctx.stroke(path, with: .color(stroke), style: style)
            }
        }

        for line in layout { ctx.draw(line) }
    }
}

// MARK: - Arrows

/// Anchors and arrows collected for a `drawablyArrows()` layer.
struct DrawablyOverlay {
    var anchors: [String: Anchor<CGRect>] = [:]
    var arrows: [ArrowSpec] = []
}

struct ArrowSpec {
    var from: String
    var to: String
    var seed: UInt32
}

struct DrawablyOverlayKey: PreferenceKey {
    static let defaultValue = DrawablyOverlay()

    static func reduce(value: inout DrawablyOverlay, nextValue: () -> DrawablyOverlay) {
        let next = nextValue()
        value.anchors.merge(next.anchors) { _, new in new }
        value.arrows += next.arrows
    }
}

struct ArrowDeclaration: ViewModifier {
    var from: String
    var to: String
    @State var seed: UInt32

    func body(content: Content) -> some View {
        content.transformPreference(DrawablyOverlayKey.self) { value in
            value.arrows.append(ArrowSpec(from: from, to: to, seed: seed))
        }
    }
}

public extension View {
    /// Names this view as an arrow end.
    func drawablyAnchor(_ id: String) -> some View {
        anchorPreference(key: DrawablyOverlayKey.self, value: .bounds) { DrawablyOverlay(anchors: [id: $0]) }
    }

    /// Declares an annotation arrow between two anchors. It is drawn by the
    /// nearest `drawablyArrows()` above both ends.
    func drawablyArrow(from: String, to: String, seed: UInt32? = nil) -> some View {
        modifier(ArrowDeclaration(from: from, to: to, seed: seed ?? randomSeed()))
    }

    /// Draws every arrow declared inside this view, above its content. Put it on
    /// a container that holds both ends of each arrow (drawably's `<body>` overlay).
    func drawablyArrows() -> some View {
        overlayPreferenceValue(DrawablyOverlayKey.self) { overlay in
            GeometryReader { proxy in
                ForEach(overlay.arrows.indices, id: \.self) { i in
                    let spec = overlay.arrows[i]
                    if let a = overlay.anchors[spec.from], let b = overlay.anchors[spec.to] {
                        ArrowView(from: proxy[a], to: proxy[b], seed: spec.seed)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// breathing room between an anchor's box edge and the arrow's end
private let ARROW_GAP = 6.0

struct ArrowView: View {
    var from: CGRect
    var to: CGRect
    var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    var body: some View {
        let (a, b) = (from, to)
        Boiling(theme.options(seed: seed)) { o in
            RoughShape(o) { _, o in
                let ax = a.midX, ay = a.midY, bx = b.midX, by = b.midY
                let dx = bx - ax, dy = by - ay
                let len = max(hypot(dx, dy), 1)
                let ux = dx / len, uy = dy / len
                // distance along the centre line from a box's centre to its edge
                func exit(_ r: CGRect) -> Double {
                    let ex = ux == 0 ? .infinity : r.width / 2 / abs(ux)
                    let ey = uy == 0 ? .infinity : r.height / 2 / abs(uy)
                    let e = min(ex, ey)
                    return e.isFinite ? e : 0
                }
                let t0 = min(exit(a) + ARROW_GAP, len / 2)
                let t1 = min(exit(b) + ARROW_GAP, len / 2)
                return Rough.arrow(ax + ux * t0, ay + uy * t0, bx - ux * t1, by - uy * t1, o)
            }
            .pen(ink.stroke, theme.width ?? 2)
        }
    }
}
