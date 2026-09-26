import Drawably
import SwiftUI

// The example page's CSS: palette, type, the scattered "pieces" layout and its
// phone fallback, the paper grain, code colouring and the copy buttons.

enum Palette {
    static let ink = rgb(0x18181b)
    static let ink2 = rgb(0x474645)
    static let ink3 = rgb(0xa1a1aa)
    static let pen = rgb(0x2724d1)
    static let paper = rgb(0xe3e3e1)
    static let codeS = rgb(0x0f766e)
    static let codeO = rgb(0xb45309)
    static let codeP = rgb(0x71717a)

    static func rgb(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

extension Font {
    /// `.note` — 13px Inter.
    static let note = Font.drawablyInter(13)
    /// `.fn` / `.meta` — 12.5px Geist Mono.
    static let fn = Font.drawablyMono(12.5)
}

/// `--ease`
let pageEase = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.7)

// MARK: - Pieces

/// Where a piece sits on a wide board: CSS `top/left/right/bottom` as fractions
/// of the board, and its `rotate`.
struct Place {
    var top: CGFloat?
    var left: CGFloat?
    var right: CGFloat?
    var bottom: CGFloat?
    var rotate: Double = 0
    var delay: Double = 0
}

private struct PlaceKey: LayoutValueKey {
    static let defaultValue: Place? = nil
}

/// Absolutely positioned pieces over a centred brand (the wide layout).
struct Scatter: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for view in subviews {
            guard let p = view[PlaceKey.self] else {
                // .brand: inset 0, place-content centre, 24px padding
                let inner = ProposedViewSize(width: bounds.width - 48, height: nil)
                view.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: inner)
                continue
            }
            let size = view.sizeThatFits(.unspecified)
            var x = bounds.midX, ax = 0.5, y = bounds.midY, ay = 0.5
            if let l = p.left { x = bounds.minX + l * bounds.width; ax = 0 } else if let r = p.right { x = bounds.maxX - r * bounds.width; ax = 1 }
            if let t = p.top { y = bounds.minY + t * bounds.height; ay = 0 } else if let b = p.bottom { y = bounds.maxY - b * bounds.height; ay = 1 }
            view.place(at: CGPoint(x: x, y: y), anchor: UnitPoint(x: ax, y: ay), proposal: ProposedViewSize(size))
        }
    }
}

/// `flex-wrap: wrap; justify-content: center; align-items: center` — the phone layout.
struct Flow: Layout {
    var hSpacing: CGFloat = 22
    var vSpacing: CGFloat = 18

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + s.width > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((i, s))
            x += s.width + hSpacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rs = rows(width, subviews)
        let height = rs.map { $0.map(\.1.height).max() ?? 0 }.reduce(0, +) + vSpacing * CGFloat(max(0, rs.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(bounds.width, subviews) {
            let rowWidth = row.map(\.1.width).reduce(0, +) + hSpacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map(\.1.height).max() ?? 0
            var x = bounds.midX - rowWidth / 2
            for (i, s) in row {
                subviews[i].place(at: CGPoint(x: x, y: y + rowHeight / 2), anchor: .leading, proposal: ProposedViewSize(s))
                x += s.width + hSpacing
            }
            y += rowHeight + vSpacing
        }
    }
}

extension EnvironmentValues {
    @Entry var compact = false
    @Entry var appeared = false
    /// Steps of the `-autoplay` script (screen recordings); 0 when not autoplaying.
    @Entry var autoplayTick = 0
}

/// One pass of the autoplay script, in ticks of 0.9s.
let autoplayCycle = 26

/// `.piece`: placed and rotated on a wide board, static in the phone layout,
/// fading up 10px on load after its delay.
private struct Piece: ViewModifier {
    var place: Place
    @Environment(\.compact) private var compact
    @Environment(\.appeared) private var appeared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(compact ? 0 : place.rotate))
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : pageEase.delay(place.delay), value: appeared)
            .layoutValue(key: PlaceKey.self, value: place)
    }
}

extension View {
    func piece(top: CGFloat? = nil, left: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil, rotate: Double = 0, delay: Double = 0) -> some View {
        modifier(Piece(place: Place(top: top.map { $0 / 100 }, left: left.map { $0 / 100 }, right: right.map { $0 / 100 }, bottom: bottom.map { $0 / 100 }, rotate: rotate, delay: delay)))
    }

    /// `.brand` fade-in (the hero's lands 80ms in).
    func brandEntrance(delay: Double = 0) -> some View {
        modifier(BrandEntrance(delay: delay))
    }
}

private struct BrandEntrance: ViewModifier {
    var delay: Double
    @Environment(\.appeared) private var appeared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : pageEase.delay(delay), value: appeared)
    }
}

/// A full-height section: scattered pieces round a centred brand when wide,
/// brand then a wrapped row of pieces at 720pt and below.
struct Board<Brand: View, Pieces: View>: View {
    var size: CGSize
    @ViewBuilder var brand: Brand
    @ViewBuilder var pieces: Pieces

    var body: some View {
        let compact = size.width <= 720
        Group {
            if compact {
                VStack(spacing: 28) {
                    brand
                    Flow { pieces }
                }
                .padding(EdgeInsets(top: 48, leading: 20, bottom: 40, trailing: 20))
                .frame(maxWidth: .infinity, minHeight: size.height)
            } else {
                Scatter {
                    brand
                    pieces
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .environment(\.compact, compact)
    }
}

// MARK: - Paper grain

/// `body::after`: fractal noise at 3.5% over the whole page.
struct PaperGrain: View {
    private static let tile: CGImage? = {
        let side = 140
        var bytes = [UInt8](repeating: 0, count: side * side)
        var rng = SystemRandomNumberGenerator()
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255, using: &rng) }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }()

    var body: some View {
        if let tile = Self.tile {
            Rectangle()
                .fill(ImagePaint(image: Image(decorative: tile, scale: 1)))
                .opacity(0.035)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Code

/// Colours a Swift snippet the way the page colours its JS: keywords pen,
/// strings and enum cases teal, labels amber, names ink, punctuation grey.
func highlight(_ code: String) -> AttributedString {
    let token = /"[^"]*"|\.[a-z]\w*|\b(?:import|let|var|true|false)\b|\w+(?=:)|[A-Za-z_$]\w*|[(){}\[\],;.<>=]/
    var out = AttributedString()
    func add(_ s: Substring, _ c: Color) {
        var a = AttributedString(String(s))
        a.foregroundColor = c
        out += a
    }
    var rest = code[...]
    while let m = rest.firstMatch(of: token) {
        add(rest[rest.startIndex..<m.range.lowerBound], Palette.ink)
        let t = m.output
        let color: Color =
            t.hasPrefix("\"") || t.hasPrefix(".") && t.count > 1 ? Palette.codeS
            : ["import", "let", "var", "true", "false"].contains(t) ? Palette.pen
            : rest[m.range.upperBound...].hasPrefix(":") ? Palette.codeO
            : t.first!.isLetter || t.first == "_" || t.first == "$" ? Palette.ink
            : Palette.codeP
        add(t, color)
        rest = rest[m.range.upperBound...]
    }
    add(rest, Palette.ink)
    return out
}

/// `<pre>`: 12.5px Geist Mono at line-height 1.7.
struct CodeBlock: View {
    var code: String

    var body: some View {
        Text(highlight(code))
            .font(.drawablyMono(12.5))
            .lineSpacing(12.5 * 0.7 - 2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Copy

enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

/// The copy glyph that blurs into a tick for 1.4s after a copy.
struct CopyIcons: View {
    var copied: Bool
    var size: CGFloat = 16
    var color: Color = Palette.pen
    var lineWidth: CGFloat = 1.6

    var body: some View {
        ZStack {
            icon(CopyGlyph(), shown: !copied)
            icon(TickGlyph(), shown: copied)
        }
        .frame(width: size, height: size)
        .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.3), value: copied)
    }

    private func icon(_ shape: some Shape, shown: Bool) -> some View {
        shape
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * 16 / size, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .scaleEffect(size / 16)
            .frame(width: size, height: size)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.25)
            .blur(radius: shown ? 0 : 4)
    }
}

/// viewBox 0 0 16 16: a front sheet and the corner of the one behind it.
struct CopyGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: 5.5, y: 5.5, width: 8, height: 8), cornerRadius: 1.2)
        p.move(to: CGPoint(x: 10.5, y: 5.5))
        p.addLine(to: CGPoint(x: 10.5, y: 4.2))
        p.addArc(tangent1End: CGPoint(x: 10.5, y: 3), tangent2End: CGPoint(x: 9.3, y: 3), radius: 1.2)
        p.addLine(to: CGPoint(x: 4.2, y: 3))
        p.addArc(tangent1End: CGPoint(x: 3, y: 3), tangent2End: CGPoint(x: 3, y: 4.2), radius: 1.2)
        p.addLine(to: CGPoint(x: 3, y: 9.3))
        p.addArc(tangent1End: CGPoint(x: 3, y: 10.5), tangent2End: CGPoint(x: 4.2, y: 10.5), radius: 1.2)
        p.addLine(to: CGPoint(x: 5.5, y: 10.5))
        return p
    }
}

struct TickGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 3.5, y: 8.5))
        p.addLine(to: CGPoint(x: 6.5, y: 11.5))
        p.addLine(to: CGPoint(x: 12.5, y: 4.5))
        return p
    }
}

/// Presses shrink to 96%.
struct ShrinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.12), value: configuration.isPressed)
    }
}

/// Shows the tick for 1.4s after `copy()`.
@MainActor @Observable final class CopyFlash {
    var copied = false
    private var task: Task<Void, Never>?

    func copy(_ text: String) {
        Clipboard.copy(text)
        copied = true
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if !Task.isCancelled { copied = false }
        }
    }
}
