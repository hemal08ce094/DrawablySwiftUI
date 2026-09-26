import SwiftUI

// MARK: - Divider

/// A rough horizontal rule, 10pt tall. `drawablyDivider`.
public struct DrawablyDivider: View {
    @State private var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    public init(seed: UInt32? = nil) {
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        Boiling(theme.options(seed: seed)) { o in
            RoughShape(o) { s, o in Rough.line(INSET, s.height / 2, s.width - INSET, s.height / 2, o) }
                .pen(ink.stroke, theme.width ?? 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// A sketched container with 16pt padding. `drawablyCard`.
public struct DrawablyCard<Content: View>: View {
    var padding: EdgeInsets
    var content: Content
    @State private var seed: UInt32

    public init(padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16), seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        content
            .padding(padding)
            .drawablyCardFrame(seed: seed)
    }
}

extension View {
    /// The card outline (r10) behind any view, at its own size.
    func drawablyCardFrame(seed: UInt32) -> some View {
        background { CardFrame(seed: seed) }
    }
}

struct CardFrame: View {
    var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    var body: some View {
        Boiling(theme.options(seed: seed)) { o in
            RoughShape(o, Gen.outlineRect(10)).pen(ink.stroke, theme.width ?? 2)
        }
    }
}

// MARK: - Badge

public enum DrawablyBadgeVariant: Sendable { case outline, scribble }

/// A tight, sharp-cornered tag in Geist Mono. `drawablyBadge`.
public struct DrawablyBadge<Content: View>: View {
    var variant: DrawablyBadgeVariant
    var roughnessScale: Double
    var padding: EdgeInsets
    var content: Content
    @State private var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    public init(variant: DrawablyBadgeVariant = .outline, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.init(variant: variant, roughnessScale: 1, padding: EdgeInsets(top: 1, leading: 7, bottom: 1, trailing: 7), seed: seed, content: content)
    }

    init(variant: DrawablyBadgeVariant, roughnessScale: Double, padding: EdgeInsets, seed: UInt32?, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.roughnessScale = roughnessScale
        self.padding = padding
        self.content = content()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        content
            .font(.drawablyMono(theme.monoSize, weight: .medium))
            .lineSpacing(theme.monoSize * 0.15)
            .foregroundStyle(ink.stroke)
            .padding(padding)
            .background {
                Boiling(theme.options(seed: seed, roughnessScale: roughnessScale)) { o in
                    ZStack {
                        if variant == .scribble {
                            RoughShape(o) { s, o in
                                Rough.scribbleFill(INSET + 1, INSET + 1, s.width - 2 * INSET - 2, s.height - 2 * INSET - 2, o)
                            }
                            .pen(ink.stroke, 1.5)
                        }
                        RoughShape(o, Gen.outlineRect(2)).pen(ink.stroke, theme.width ?? 2)
                    }
                }
            }
    }
}

public extension DrawablyBadge where Content == Text {
    init(_ title: LocalizedStringKey, variant: DrawablyBadgeVariant = .outline, seed: UInt32? = nil) {
        self.init(variant: variant, seed: seed) { Text(title) }
    }

    @_disfavoredOverload
    init<S: StringProtocol>(_ title: S, variant: DrawablyBadgeVariant = .outline, seed: UInt32? = nil) {
        self.init(variant: variant, seed: seed) { Text(title) }
    }
}

// MARK: - List

public enum DrawablyListMarker: Sendable { case dash, check }

// marker geometry in the list's 24pt left gutter; it sits on the middle of
// each item's first line
private let MARKER_LEFT = -18.0
private let MARKER_W = 10.0

/// A list with one sketched marker per item. Each child view is an item.
public struct DrawablyList<Content: View>: View {
    var marker: DrawablyListMarker
    var lineHeight: CGFloat
    var spacing: CGFloat
    var content: Content
    @State private var seed: UInt32

    /// - Parameter lineHeight: the height of an item's first line; the marker centres on it.
    public init(marker: DrawablyListMarker = .dash, lineHeight: CGFloat = 22, spacing: CGFloat = 0, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.marker = marker
        self.lineHeight = lineHeight
        self.spacing = spacing
        self.content = content()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Group(subviews: content) { items in
                ForEach(items.indices, id: \.self) { i in
                    ListItem(marker: marker, lineHeight: lineHeight, seed: seed &+ UInt32(i), item: items[i])
                }
            }
        }
        .padding(.leading, 24)
    }
}

private struct ListItem: View {
    var marker: DrawablyListMarker
    var lineHeight: CGFloat
    var seed: UInt32
    var item: Subview
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    var body: some View {
        item
            .frame(minHeight: lineHeight)
            .overlay(alignment: .topLeading) {
                Boiling(theme.options(seed: seed)) { o in
                    RoughShape(o) { [marker] _, o in
                        switch marker {
                        case .check: Rough.checkmark(0, 0, MARKER_W, MARKER_W, o)
                        case .dash: Rough.line(0, MARKER_W / 2, MARKER_W, MARKER_W / 2, o)
                        }
                    }
                    .pen(ink.stroke, theme.width ?? 2)
                }
                .frame(width: MARKER_W, height: MARKER_W)
                .offset(x: MARKER_LEFT, y: lineHeight / 2 - MARKER_W / 2)
                .accessibilityHidden(true)
            }
    }
}
