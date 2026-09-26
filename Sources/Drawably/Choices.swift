import SwiftUI

// Checkbox, radio and toggle. drawably keeps a real <input> under the sketch;
// here a Button carries the tap, keyboard focus and accessibility.

/// The tappable row shared by checkbox, radio and toggle: the sketched box, then
/// an optional label 10pt away. Presses re-sketch.
struct ChoiceRow<Box: View, Label: View>: View {
    @Binding var seed: UInt32
    var action: () -> Void
    var box: Box
    var label: Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                box.resketch($seed)
                label
            }
        }
        .buttonStyle(PressReportingStyle { down in
            if down, !reduceMotion { seed = randomSeed() }
        })
    }
}

// MARK: - Checkbox

public struct DrawablyCheckbox<Label: View>: View {
    @Binding var isOn: Bool
    var label: Label
    @State private var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink
    @Environment(\.isFocused) private var isFocused

    public init(isOn: Binding<Bool>, seed: UInt32? = nil, @ViewBuilder label: () -> Label) {
        _isOn = isOn
        self.label = label()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        ChoiceRow(seed: $seed, action: { isOn.toggle() }, box: box, label: label)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(isOn ? Text("checked") : Text("unchecked"))
    }

    private var box: some View {
        let width = theme.width ?? 2
        return Color.clear
            .frame(width: 22, height: 22)
            .background {
                Boiling(theme.options(seed: seed)) { o in
                    ZStack {
                        RoughShape(o, Gen.outlineRect(5)).pen(ink.stroke, width)
                        RoughShape(o) { s, o in
                            Rough.checkmark(s.width * 0.24, s.height * 0.2, s.width * 0.52, s.height * 0.5, o)
                        }
                        .trim(from: 0, to: isOn ? 1 : 0)
                        .pen(ink.stroke, width)
                        .motion(.drawablyEase(0.24), value: isOn)
                        RoughShape(o, Gen.focusRect(7)).pen(ink.stroke, 1.5).opacity(isFocused ? 1 : 0)
                    }
                }
            }
    }
}

public extension DrawablyCheckbox where Label == EmptyView {
    init(isOn: Binding<Bool>, seed: UInt32? = nil) {
        self.init(isOn: isOn, seed: seed) { EmptyView() }
    }
}

public extension DrawablyCheckbox where Label == Text {
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, seed: UInt32? = nil) {
        self.init(isOn: isOn, seed: seed) { Text(title) }
    }
}

// MARK: - Radio

public struct DrawablyRadio<Value: Hashable, Label: View>: View {
    var value: Value
    @Binding var selection: Value
    var label: Label
    @State private var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink
    @Environment(\.isFocused) private var isFocused

    public init(value: Value, selection: Binding<Value>, seed: UInt32? = nil, @ViewBuilder label: () -> Label) {
        self.value = value
        _selection = selection
        self.label = label()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    private var checked: Bool { selection == value }

    public var body: some View {
        ChoiceRow(seed: $seed, action: { selection = value }, box: box, label: label)
            .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)
    }

    private var box: some View {
        let width = theme.width ?? 2
        return Color.clear
            .frame(width: 22, height: 22)
            .background {
                Boiling(theme.options(seed: seed)) { o in
                    ZStack {
                        RoughShape(o) { s, o in
                            Rough.circle(s.width / 2, s.height / 2, min(s.width, s.height) / 2 - INSET, o)
                        }
                        .pen(ink.stroke, width)
                        // the dot hides at once but grows in from half size
                        RoughShape(o) { s, o in
                            Rough.circle(s.width / 2, s.height / 2, min(s.width, s.height) * 0.18, o)
                        }
                        .fill(ink.fill)
                        .stroke(ink.fill, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                        .scaleEffect(checked ? 1 : 0.5)
                        .motion(.drawablyEase(0.16), value: checked)
                        .opacity(checked ? 1 : 0)
                        .animation(nil, value: checked)
                        RoughShape(o) { s, o in
                            Rough.circle(s.width / 2, s.height / 2, min(s.width, s.height) / 2 + 1, o)
                        }
                        .pen(ink.stroke, 1.5)
                        .opacity(isFocused ? 1 : 0)
                    }
                }
            }
    }
}

public extension DrawablyRadio where Label == EmptyView {
    init(value: Value, selection: Binding<Value>, seed: UInt32? = nil) {
        self.init(value: value, selection: selection, seed: seed) { EmptyView() }
    }
}

public extension DrawablyRadio where Label == Text {
    init(_ title: LocalizedStringKey, value: Value, selection: Binding<Value>, seed: UInt32? = nil) {
        self.init(value: value, selection: selection, seed: seed) { Text(title) }
    }
}

// MARK: - Toggle

public struct DrawablyToggle<Label: View>: View {
    @Binding var isOn: Bool
    var label: Label
    @State private var seed: UInt32
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink
    @Environment(\.isFocused) private var isFocused

    public init(isOn: Binding<Bool>, seed: UInt32? = nil, @ViewBuilder label: () -> Label) {
        _isOn = isOn
        self.label = label()
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        ChoiceRow(seed: $seed, action: { isOn.toggle() }, box: box, label: label)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(isOn ? Text("on") : Text("off"))
    }

    private var box: some View {
        let width = theme.width ?? 2
        return Color.clear
            .frame(width: 44, height: 24)
            .background {
                Boiling(theme.options(seed: seed)) { o in
                    ZStack {
                        RoughShape(o) { s, o in
                            Gen.outlineRect((s.height - 2 * INSET) / 2)(s, o)
                        }
                        .pen(ink.stroke, width)
                        // travel = width 44 minus height 24
                        RoughShape(o) { s, o in
                            Rough.circle(s.height / 2, s.height / 2, s.height / 2 - INSET - 3, o)
                        }
                        .blob(ink.fill)
                        .offset(x: isOn ? 20 : 0)
                        .motion(.drawablyEase(0.16), value: isOn)
                        RoughShape(o, Gen.focusRect(12)).pen(ink.stroke, 1.5).opacity(isFocused ? 1 : 0)
                    }
                }
            }
    }
}

public extension DrawablyToggle where Label == EmptyView {
    init(isOn: Binding<Bool>, seed: UInt32? = nil) {
        self.init(isOn: isOn, seed: seed) { EmptyView() }
    }
}

public extension DrawablyToggle where Label == Text {
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, seed: UInt32? = nil) {
        self.init(isOn: isOn, seed: seed) { Text(title) }
    }
}
