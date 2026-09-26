import SwiftUI

public enum DrawablyButtonVariant: Sendable { case outline, solid, scribble }
public enum DrawablyButtonState: Sendable { case idle, loading, error, success }
public enum DrawablyTone: Sendable { case pen, neutral, danger }

/// A hand-drawn button. `drawablyButton(el, opts)` / `<DrawablyButton>`.
public struct DrawablyButton<Label: View>: View {
    var variant: DrawablyButtonVariant
    var tone: DrawablyTone
    var state: DrawablyButtonState
    var seed: UInt32?
    var action: () -> Void
    var label: Label

    public init(
        variant: DrawablyButtonVariant = .outline,
        tone: DrawablyTone = .pen,
        state: DrawablyButtonState = .idle,
        seed: UInt32? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.tone = tone
        self.state = state
        self.seed = seed
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) { label }
            .buttonStyle(DrawablyButtonStyle(variant: variant, tone: tone, state: state, seed: seed))
    }
}

public extension DrawablyButton where Label == Text {
    init(
        _ title: LocalizedStringKey,
        variant: DrawablyButtonVariant = .outline,
        tone: DrawablyTone = .pen,
        state: DrawablyButtonState = .idle,
        seed: UInt32? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.init(variant: variant, tone: tone, state: state, seed: seed, action: action) { Text(title) }
    }

    @_disfavoredOverload
    init<S: StringProtocol>(
        _ title: S,
        variant: DrawablyButtonVariant = .outline,
        tone: DrawablyTone = .pen,
        state: DrawablyButtonState = .idle,
        seed: UInt32? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.init(variant: variant, tone: tone, state: state, seed: seed, action: action) { Text(title) }
    }
}

/// The sketch as a `ButtonStyle`, for any `Button`: `.buttonStyle(.drawably(variant: .solid))`.
public struct DrawablyButtonStyle: ButtonStyle {
    public var variant: DrawablyButtonVariant
    public var tone: DrawablyTone
    public var state: DrawablyButtonState
    public var seed: UInt32?

    public init(variant: DrawablyButtonVariant = .outline, tone: DrawablyTone = .pen, state: DrawablyButtonState = .idle, seed: UInt32? = nil) {
        self.variant = variant
        self.tone = tone
        self.state = state
        self.seed = seed
    }

    public func makeBody(configuration: Configuration) -> some View {
        ButtonSketch(configuration: configuration, variant: variant, tone: tone, state: state, initialSeed: seed)
    }
}

public extension ButtonStyle where Self == DrawablyButtonStyle {
    static var drawably: DrawablyButtonStyle { DrawablyButtonStyle() }

    static func drawably(
        variant: DrawablyButtonVariant = .outline, tone: DrawablyTone = .pen,
        state: DrawablyButtonState = .idle, seed: UInt32? = nil
    ) -> DrawablyButtonStyle {
        DrawablyButtonStyle(variant: variant, tone: tone, state: state, seed: seed)
    }
}

struct ButtonSketch: View {
    let configuration: ButtonStyleConfiguration
    let variant: DrawablyButtonVariant
    let tone: DrawablyTone
    let state: DrawablyButtonState
    @State private var seed: UInt32
    @State private var hovering = false
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(configuration: ButtonStyleConfiguration, variant: DrawablyButtonVariant, tone: DrawablyTone, state: DrawablyButtonState, initialSeed: UInt32?) {
        self.configuration = configuration
        self.variant = variant
        self.tone = tone
        self.state = state
        _seed = State(initialValue: initialSeed ?? randomSeed())
    }

    /// Tone sets stroke and fill; an error/success state overrides both (`--drawably-ink`).
    private var ink: Ink {
        switch state {
        case .error: return Ink(stroke: theme.error, fill: theme.error)
        case .success: return Ink(stroke: theme.success, fill: theme.success)
        default: break
        }
        switch tone {
        case .pen: return Ink(stroke: theme.stroke, fill: theme.fill)
        case .neutral: return Ink(stroke: theme.neutral, fill: theme.neutral)
        case .danger: return Ink(stroke: theme.error, fill: theme.error)
        }
    }

    private var pressed: Bool { configuration.isPressed && isEnabled }
    private var lifted: Bool { hovering && isEnabled && state != .loading && !pressed }
    private var washed: Bool { hovering && isEnabled && variant != .solid }

    var body: some View {
        let ink = ink
        let width = theme.width ?? 2
        configuration.label
            .font(theme.font)
            .foregroundStyle(variant == .solid ? theme.paper : ink.stroke)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background {
                Boiling(theme.options(seed: seed), cycle: state == .loading ? 0.45 : 1.2) { o in
                    ZStack {
                        if variant == .solid {
                            RoughShape(o, Gen.outlineRect(8)).blob(ink.fill)
                        }
                        if variant == .scribble {
                            RoughShape(o) { s, o in
                                Rough.scribbleFill(INSET + 2, INSET + 2, s.width - 2 * INSET - 4, s.height - 2 * INSET - 4, o)
                            }
                            .pen(ink.stroke, 1.5)
                        }
                        RoughShape(o, Gen.outlineRect(8))
                            .fill(washed ? ink.stroke.opacity(0.1) : .clear)
                            .stroke(ink.stroke, style: StrokeStyle(lineWidth: pressed ? width * 1.4 : width, lineCap: .round, lineJoin: .round))
                        RoughShape(o, Gen.focusRect(10))
                            .pen(ink.stroke, 1.5)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .animation(.cssEase(0.12), value: washed)
                .animation(.cssEase(0.12), value: pressed)
            }
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.45 : state == .loading ? 0.6 : 1)
            .scaleEffect(pressed ? 0.98 : 1)
            .offset(y: pressed ? 1 : lifted ? -1 : 0)
            .animation(.cssEase(0.12), value: pressed)
            .animation(.cssEase(0.12), value: lifted)
            .onHover { hovering = $0 }
            .resketch($seed, enabled: isEnabled)
            .onChange(of: configuration.isPressed) { _, down in
                if down, isEnabled, !reduceMotion { seed = randomSeed() }
            }
    }
}
