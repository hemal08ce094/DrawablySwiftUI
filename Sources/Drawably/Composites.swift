import SwiftUI

// Pieces built from the controls. One `seed` reproduces every stroke in the
// piece: part k is drawn with `seed + k`, as in drawably's composites.

// MARK: - Chip

/// A badge around the whole chip, a (0.8×) checkbox inside it.
public struct DrawablyChip<Label: View>: View {
    @Binding var isOn: Bool
    var label: Label
    private let seed: UInt32

    public init(isOn: Binding<Bool>, seed: UInt32? = nil, @ViewBuilder label: () -> Label) {
        _isOn = isOn
        self.label = label()
        self.seed = seed ?? randomSeed()
    }

    public var body: some View {
        DrawablyBadge(variant: .outline, roughnessScale: 1, padding: EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 10), seed: seed) {
            HStack(spacing: 8) {
                DrawablyCheckbox(isOn: $isOn, seed: seed &+ 1)
                    .scaleEffect(0.8)
                    .frame(width: 22 * 0.8, height: 22 * 0.8)
                label
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

public extension DrawablyChip where Label == Text {
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, seed: UInt32? = nil) {
        self.init(isOn: isOn, seed: seed) { Text(title) }
    }
}

// MARK: - Tabs

/// Children are the tabs; an underline follows the active one.
public struct DrawablyTabs<Content: View>: View {
    @Binding var selection: Int
    var content: Content
    @State private var seed: UInt32

    public init(selection: Binding<Int>, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        _selection = selection
        self.content = content()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        HStack(spacing: 18) {
            Group(subviews: content) { tabs in
                ForEach(tabs.indices, id: \.self) { i in
                    let active = i == min(max(selection, 0), tabs.count - 1)
                    Button { selection = i } label: {
                        tabs[i]
                            // same seed on whichever tab is active: the line moves, the stroke stays
                            .modifier(TabUnderline(active: active, seed: $seed))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? [.isSelected] : [])
                }
            }
        }
    }
}

private struct TabUnderline: ViewModifier {
    var active: Bool
    @Binding var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    func body(content: Content) -> some View {
        content
            .background {
                if active {
                    Boiling(theme.options(seed: seed)) { o in
                        RoughShape(o) { s, o in DrawablyMarkKind.underline.path(s, o) }
                            .pen(ink.stroke, theme.width ?? 1.5)
                    }
                }
            }
            .resketch($seed, enabled: active)
    }
}

// MARK: - Tooltip

/// A card around the tip and an arrow from it to the view anchored as `target`
/// (`.drawablyAnchor(target)`). Needs a `drawablyArrows()` container.
public struct DrawablyTooltip<Content: View>: View {
    var target: String
    var content: Content
    private let seed: UInt32
    @State private var id = "drawably-tooltip-\(UUID().uuidString)"

    public init(to target: String, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.target = target
        self.content = content()
        self.seed = seed ?? randomSeed()
    }

    public var body: some View {
        DrawablyCard(padding: EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10), seed: seed) { content }
            .drawablyAnchor(id)
            .drawablyArrow(from: id, to: target, seed: seed &+ 1)
    }
}

public extension DrawablyTooltip where Content == Text {
    init(_ title: LocalizedStringKey, to target: String, seed: UInt32? = nil) {
        self.init(to: target, seed: seed) { Text(title) }
    }
}

// MARK: - Alert

/// A card around the alert, with an optional badge tag at its start.
public struct DrawablyAlert<Content: View>: View {
    var tag: String?
    var content: Content
    private let seed: UInt32

    public init(tag: String? = nil, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.tag = tag
        self.content = content()
        self.seed = seed ?? randomSeed()
    }

    public var body: some View {
        DrawablyCard(padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12), seed: seed) {
            HStack(spacing: 8) {
                if let tag {
                    DrawablyBadge(variant: .outline, roughnessScale: 1, padding: EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6), seed: seed &+ 1) {
                        Text(tag)
                    }
                }
                content
            }
        }
    }
}

// MARK: - Steps

/// A check-marked list.
public struct DrawablySteps<Content: View>: View {
    var content: Content
    var lineHeight: CGFloat
    private let seed: UInt32?

    public init(lineHeight: CGFloat = 22, seed: UInt32? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.lineHeight = lineHeight
        self.seed = seed
    }

    public var body: some View {
        DrawablyList(marker: .check, lineHeight: lineHeight, seed: seed) { content }
    }
}

// MARK: - Kbd

// keys are drawn with a steadier hand than prose
private let KBD_ROUGHNESS = 0.6

/// A key cap: a badge with a steadier hand.
public struct DrawablyKbd: View {
    var key: String
    private let seed: UInt32?
    @Environment(\.drawablyTheme) private var theme

    public init(_ key: String, seed: UInt32? = nil) {
        self.key = key
        self.seed = seed
    }

    public var body: some View {
        DrawablyBadge(variant: .outline, roughnessScale: KBD_ROUGHNESS, padding: EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8), seed: seed) {
            Text(key)
        }
        .drawablyTheme { $0.monoSize = 13 }
    }
}

// MARK: - Quote

/// A highlight on the line, and a divider above an optional footer.
public struct DrawablyQuote<Footer: View>: View {
    var line: Text
    var footer: Footer
    private let seed: UInt32

    public init(_ line: Text, seed: UInt32? = nil, @ViewBuilder footer: () -> Footer) {
        self.line = line
        self.footer = footer()
        self.seed = seed ?? randomSeed()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line.drawablyHighlight(seed: seed)
            if Footer.self != EmptyView.self {
                VStack(alignment: .leading, spacing: 8) {
                    DrawablyDivider(seed: seed &+ 1)
                    footer
                }
                .padding(.top, 10)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

public extension DrawablyQuote where Footer == EmptyView {
    init(_ line: Text, seed: UInt32? = nil) {
        self.init(line, seed: seed) { EmptyView() }
    }
}

// MARK: - Pager

/// Page buttons: every page outlined, the current one solid. Changing page
/// redraws only the two buttons that swap.
public struct DrawablyPager: View {
    @Binding var page: Int
    var count: Int
    private let seed: UInt32

    public init(page: Binding<Int>, count: Int, seed: UInt32? = nil) {
        _page = page
        self.count = count
        self.seed = seed ?? randomSeed()
    }

    public var body: some View {
        HStack(spacing: 6) {
            button(0, "‹") { page = max(0, page - 1) }
            ForEach(0..<count, id: \.self) { i in
                button(i + 1, "\(i + 1)", current: i == page) { page = i }
            }
            button(count + 1, "›") { page = min(count - 1, page + 1) }
        }
    }

    private func button(_ slot: Int, _ title: String, current: Bool = false, action: @escaping () -> Void) -> some View {
        // min width 34 including the 14pt side padding
        DrawablyButton(variant: current ? .solid : .outline, seed: seed &+ UInt32(slot), action: action) {
            Text(title).frame(minWidth: 34 - 28)
        }
        // a fresh identity when a page swaps variant, so it is sketched anew
        .id("\(slot)-\(current)")
            .accessibilityAddTraits(current ? .isSelected : [])
    }
}
