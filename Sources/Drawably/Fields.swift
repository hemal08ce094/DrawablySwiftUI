import SwiftUI

// Input, textarea and select. The sketch sits behind a real field; the focus
// ring shows whenever the field has focus, like :focus-visible on inputs.

/// Outline r6 plus focus ring r8, the frame every field shares (`fieldBox`).
struct FieldFrame<Extra: View>: View {
    var seed: UInt32
    var focused: Bool
    var extra: (RoughOptions) -> Extra
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    var body: some View {
        Boiling(theme.options(seed: seed)) { o in
            ZStack {
                RoughShape(o, Gen.outlineRect(6)).pen(ink.stroke, theme.width ?? 2)
                extra(o)
                RoughShape(o, Gen.focusRect(8)).pen(ink.stroke, 1.5).opacity(focused ? 1 : 0)
            }
        }
    }
}

extension FieldFrame where Extra == EmptyView {
    init(seed: UInt32, focused: Bool) {
        self.init(seed: seed, focused: focused) { _ in EmptyView() }
    }
}

// MARK: - Input

public struct DrawablyTextField: View {
    var placeholder: String
    @Binding var text: String
    @State private var seed: UInt32
    @FocusState private var focused: Bool
    @Environment(\.drawablyTheme) private var theme

    public init(_ placeholder: String = "", text: Binding<String>, seed: UInt32? = nil) {
        self.placeholder = placeholder
        _text = text
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        TextField(text: $text, prompt: Text(placeholder).foregroundStyle(theme.placeholder)) {
            Text(placeholder)
        }
        .textFieldStyle(.plain)
        .focused($focused)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background { FieldFrame(seed: seed, focused: focused) }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

// MARK: - Textarea

public struct DrawablyTextEditor: View {
    var placeholder: String
    @Binding var text: String
    var rows: Int
    @State private var seed: UInt32
    @FocusState private var focused: Bool
    @Environment(\.drawablyTheme) private var theme

    /// - Parameter rows: visible lines, like `<textarea rows>`.
    public init(_ placeholder: String = "", text: Binding<String>, rows: Int = 2, seed: UInt32? = nil) {
        self.placeholder = placeholder
        _text = text
        self.rows = rows
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        TextField(text: $text, prompt: Text(placeholder).foregroundStyle(theme.placeholder), axis: .vertical) {
            Text(placeholder)
        }
        .lineLimit(rows, reservesSpace: true)
        .textFieldStyle(.plain)
        .focused($focused)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background { FieldFrame(seed: seed, focused: focused) }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

// MARK: - Select

// chevron sits in the right-hand gutter the padding reserves; at this size
// full roughness turns the V into noise, so it takes a fraction
private let CHEVRON_W = 12.0
private let CHEVRON_H = 6.0
private let CHEVRON_RIGHT = 12.0
private let CHEVRON_ROUGHNESS = 0.4
private let PICKER_RADIUS = 6.0
private let CHECK_BOX = 14.0
private let CHECK_INSET = 2.0

/// A select with a sketched chevron and a sketched options list with a pen check.
/// Its width is reserved for the widest option, so picking never shifts layout.
public struct DrawablySelect<Value: Hashable>: View {
    @Binding var selection: Value
    var options: [Value]
    var title: (Value) -> String
    @State private var seed: UInt32
    @State private var open = false
    @State private var fieldSize: CGSize = .zero
    @FocusState private var focused: Bool
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    public init(selection: Binding<Value>, options: [Value], seed: UInt32? = nil, title: @escaping (Value) -> String) {
        _selection = selection
        self.options = options
        self.title = title
        _seed = State(initialValue: seed ?? randomSeed())
    }

    public var body: some View {
        Button { open.toggle() } label: {
            ZStack(alignment: .leading) {
                // every option laid out invisibly reserves the widest one's width
                ForEach(options, id: \.self) { Text(title($0)).hidden() }
                Text(title(selection))
            }
            .font(theme.font)
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .padding(.trailing, 34)
            .background {
                FieldFrame(seed: seed, focused: focused || open) { o in
                    RoughShape(o) { s, o in
                        let x = s.width - CHEVRON_RIGHT - CHEVRON_W
                        let y = s.height / 2 - CHEVRON_H / 2
                        var co = o
                        co.roughness *= CHEVRON_ROUGHNESS
                        var second = co
                        second.seed = o.seed &+ 1
                        var p = Rough.line(x, y, x + CHEVRON_W / 2, y + CHEVRON_H, co)
                        p.addPath(Rough.line(x + CHEVRON_W / 2, y + CHEVRON_H, x + CHEVRON_W, y, second))
                        return p
                    }
                    .pen(ink.stroke, theme.width ?? 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { fieldSize = $0 }
        .overlay(alignment: .topLeading) {
            if open { picker }
        }
        .accessibilityValue(Text(title(selection)))
        .onKeyPress(.escape) {
            guard open else { return .ignored }
            open = false
            return .handled
        }
    }

    /// The options list: paper, a sketched frame and a pen check on the chosen one.
    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                PickerOption(label: title(option), chosen: option == selection, seed: seed) {
                    selection = option
                    open = false
                }
            }
        }
        .padding(6)
        .frame(minWidth: fieldSize.width, alignment: .leading)
        .fixedSize()
        .background(theme.paper)
        .background {
            Boiling(theme.options(seed: seed)) { o in
                RoughShape(o, Gen.outlineRect(PICKER_RADIUS)).pen(ink.stroke, theme.width ?? 2)
            }
        }
        .font(theme.font)
        .offset(y: fieldSize.height + 4)
        .background {
            // a click anywhere else closes it, like a popover's light dismiss
            Color.black.opacity(0.0001)
                .frame(width: 6000, height: 6000)
                .onTapGesture { open = false }
        }
        .zIndex(1)
    }
}

public extension DrawablySelect where Value == String {
    init(selection: Binding<String>, options: [String], seed: UInt32? = nil) {
        self.init(selection: selection, options: options, seed: seed) { $0 }
    }
}

private struct PickerOption: View {
    var label: String
    var chosen: Bool
    var seed: UInt32
    var action: () -> Void
    @State private var hovering = false
    @Environment(\.drawablyTheme) private var theme
    @Environment(\.ink) private var ink

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                // the same empty box on every option so text lines up; the chosen one
                // gets the sketched check (static: a CSS mask can't boil)
                RoughShape(theme.options(seed: seed)) { _, o in
                    let side = CHECK_BOX - CHECK_INSET * 2
                    var still = o
                    still.boilSeed = nil
                    return Rough.checkmark(CHECK_INSET, CHECK_INSET, side, side, still)
                }
                .pen(ink.stroke, 2)
                .frame(width: CHECK_BOX, height: CHECK_BOX)
                .opacity(chosen ? 1 : 0)
                Text(label)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(hovering ? ink.stroke.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 3))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
