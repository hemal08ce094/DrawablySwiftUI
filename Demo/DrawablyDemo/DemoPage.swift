import Drawably
import SwiftUI

@main
struct DrawablyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoPage()
                .preferredColorScheme(.light)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        #endif
    }
}

enum Section: String, CaseIterable, Identifiable {
    case top, install, api, compose

    var id: Self { self }

    var title: String {
        switch self {
        case .top: "Drawably"
        case .install: "Install"
        case .api: "API"
        case .compose: "Compose"
        }
    }
}

/// drawably's examples/index.html: a hero of scattered controls, then the
/// Install and API boards, plus one for the composites.
struct DemoPage: View {
    @State private var appeared = false
    @State private var frames: [Section: CGRect] = [:]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Hero(size: size).tracked(.top, into: $frames)
                        InstallBoard(size: size).tracked(.install, into: $frames)
                        ApiBoard(size: size).tracked(.api, into: $frames)
                        ComposeBoard(size: size).tracked(.compose, into: $frames)
                    }
                    // arrows live over the whole page, like drawably's <body> overlay
                    .drawablyArrows()
                }
                .coordinateSpace(.named("page"))
                .scrollIndicators(.automatic)
                .overlay(alignment: .leading) {
                    if size.width >= 840 {
                        Toc(visible: tocVisible(size), current: current(size)) { section in
                            withAnimation(.smooth) { proxy.scrollTo(section, anchor: .top) }
                        }
                        .padding(.leading, 28)
                    }
                }
            }
        }
        .font(.drawablyInter(15))
        .tracking(-0.15)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
        .overlay { PaperGrain().ignoresSafeArea() }
        .drawably(stroke: Palette.pen, fill: Palette.pen, paper: Palette.paper)
        .environment(\.appeared, appeared)
        .onAppear { appeared = true }
    }

    /// The TOC fades in once the hero is (almost) out of view.
    private func tocVisible(_ size: CGSize) -> Bool {
        guard let hero = frames[.top], hero.height > 0 else { return false }
        let visible = max(0, min(hero.maxY, size.height) - max(hero.minY, 0))
        return visible / hero.height < 0.05
    }

    /// Scroll-spy: the section crossing the band 40%–55% down the viewport.
    private func current(_ size: CGSize) -> Section {
        let top = size.height * 0.4, bottom = size.height * 0.55
        return Section.allCases.first { s in
            guard let f = frames[s] else { return false }
            return f.maxY > top && f.minY < bottom
        } ?? .install
    }
}

private extension View {
    func tracked(_ section: Section, into frames: Binding<[Section: CGRect]>) -> some View {
        id(section)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("page")) } action: { frames.wrappedValue[section] = $0 }
    }
}

// MARK: - TOC

struct Toc: View {
    var visible: Bool
    var current: Section
    var go: (Section) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Section.allCases.enumerated()), id: \.element) { i, section in
                TocLink(index: i + 1, section: section, current: section == current) { go(section) }
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 6)
                    .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.48).delay(visible ? Double(i) * 0.08 : 0), value: visible)
            }
        }
        .allowsHitTesting(visible)
    }
}

private struct TocLink: View {
    var index: Int
    var section: Section
    var current: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text("\(index).")
                    .monospacedDigit()
                    .frame(width: 14 * 1.4, alignment: .leading)
                Text(section.title)
            }
            .font(.drawablyInter(14))
            .foregroundStyle(current || hovering ? Palette.ink : Palette.ink3)
            .frame(minHeight: 40)
            .contentShape(Rectangle())
            .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.16), value: current || hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Hero

#if os(macOS)
private let reSketchVerb = "hover"
#else
private let reSketchVerb = "press"
#endif

struct Hero: View {
    var size: CGSize
    @State private var ink = "pen"
    @State private var toggled = false
    @State private var ship = true
    @State private var name = ""
    @State private var tool = "Pen"
    @State private var note = ""
    @Environment(\.compact) private var compact

    var body: some View {
        let wide = size.width > 720
        Board(size: size) {
            VStack(spacing: 0) {
                Text("drawably")
                    .font(.drawablyInter(h1, weight: .semibold))
                    .tracking(-0.04 * h1)
                DrawablyText(Text("\(Text("Hand-drawn").drawably(.underline)) UI. \(Text("Fresh pen sketch").drawably(.highlight)) \(Text("every mount").drawably(.circle))."))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
                    .padding(.top, 14)
            }
            .brandEntrance(delay: 0.08)
        } pieces: {
            DrawablyButton("Done", variant: .solid)
                .drawablyAnchor("done")
                .piece(top: 13, left: 11, rotate: -8, delay: 0.16)
            Text("\(reSketchVerb) to re-sketch")
                .font(.fn)
                .foregroundStyle(Palette.ink2)
                .drawablyAnchor("hint")
                .piece(top: 26, left: 24, rotate: -4)
            DrawablyButton("Cancel", tone: .neutral)
                .piece(top: 18, right: 12, rotate: 6, delay: 0.24)
            DrawablyButton("Save", variant: .scribble)
                .piece(top: 58, left: 8, rotate: 4, delay: 0.32)
            DrawablyButton("Wait", state: .loading)
                .piece(top: 8, left: 42, rotate: 4, delay: 0.2)
            DrawablyButton("Retry", variant: .outline, state: .error)
                .piece(top: 36, right: 6, rotate: -7, delay: 0.36)
            DrawablyButton("Saved", variant: .solid, state: .success)
                .piece(left: 40, bottom: 7, rotate: 5, delay: 0.52)
            DrawablyButton("Delete", tone: .danger)
                .piece(top: 68, right: 7, rotate: 6)
            HStack(spacing: 12) {
                DrawablyRadio("Pen", value: "pen", selection: $ink).checkLabel()
                DrawablyRadio("Pencil", value: "pencil", selection: $ink).checkLabel()
            }
            .piece(top: 38, left: 6, rotate: -4)
            DrawablyToggle(isOn: $toggled)
                .checkLabel()
                .piece(right: 14, bottom: 30, rotate: 3)
            DrawablyDivider()
                .frame(width: 88)
                .piece(top: 50, left: 28, rotate: -2)
            DrawablyCheckbox("Ship it", isOn: $ship)
                .checkLabel()
                .piece(top: 46, right: 10, rotate: -5, delay: 0.4)
            DrawablyTextField("your name", text: $name)
                .frame(width: wide ? 200 : min(260, size.width - 40))
                .piece(left: 14, bottom: 16, rotate: -3, delay: 0.48)
            DrawablySelect(selection: $tool, options: ["Pen", "Pencil", "Marker"])
                .piece(top: 62, right: 30, rotate: -3)
                .zIndex(10)
            DrawablyList(marker: .check, lineHeight: 21) {
                Text("zero deps")
                Text("real controls")
                Text("boils on one clock")
            }
            .font(.drawablyInter(14))
            .foregroundStyle(Palette.ink2)
            .piece(top: 60, left: 42, rotate: 3)
            DrawablyTextEditor("a note", text: $note, rows: 2)
                .font(.drawablyInter(14))
                .frame(width: 170)
                .piece(top: 26, right: 27, rotate: 4)
            DrawablyCard {
                Text("Every stroke is generated at load. \(reSketchVerb.capitalized) a control to re-sketch.")
                    .font(.note)
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(13 * 0.45 - 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: wide ? min(220, size.width * 0.42) : min(260, size.width - 40))
            .piece(right: 11, bottom: 12, rotate: 3, delay: 0.56)
        }
        .drawablyArrow(from: "hint", to: "done")
        .overlay(alignment: .topTrailing) {
            AgentButton()
                .padding(.top, 14)
                .padding(.trailing, 16)
        }
    }

    /// clamp(48px, 8vw, 88px)
    private var h1: CGFloat { min(max(48, size.width * 0.08), 88) }
}

private extension View {
    /// `.check-label`: 14px, second ink, at least 40pt tall.
    func checkLabel() -> some View {
        font(.drawablyInter(14))
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: 40)
    }
}

/// Copies agent.md, the port's usage notes for coding agents.
struct AgentButton: View {
    @State private var flash = CopyFlash()
    @State private var hovering = false

    var body: some View {
        Button {
            let url = Bundle.main.url(forResource: "agent", withExtension: "md")
            flash.copy(url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
        } label: {
            HStack(spacing: 6) {
                Text("agent.md")
                CopyIcons(copied: flash.copied, size: 12, color: hovering ? Palette.ink : Palette.ink3)
            }
            .font(.drawablyMono(11, weight: .medium))
            .tracking(0)
            .foregroundStyle(hovering ? Palette.ink : Palette.ink3)
            .padding(.horizontal, 8)
            .frame(minHeight: 40)
            .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.16), value: hovering)
        }
        .buttonStyle(ShrinkStyle())
        .onHover { hovering = $0 }
        .accessibilityLabel("Copy agent.md")
    }
}

// MARK: - Install

struct InstallBoard: View {
    var size: CGSize
    @State private var flash = CopyFlash()

    private let command = ".package(url: \"https://github.com/hemal08ce094/DrawablySwiftUI\", branch: \"main\")"

    var body: some View {
        let wide = size.width > 720
        Board(size: size) {
            DrawablyCard(padding: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)) {
                Button { flash.copy(command) } label: {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(Palette.ink3)
                        Text(command)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        CopyIcons(copied: flash.copied)
                    }
                    .font(.drawablyMono(13, weight: .medium))
                    .tracking(0)
                    .frame(minHeight: 40)
                }
                .buttonStyle(ShrinkStyle())
                .accessibilityLabel("Copy install line")
            }
            .fixedSize()
            .frame(maxWidth: size.width * 0.82)
            .brandEntrance()
        } pieces: {
            Text("MIT")
                .font(.fn)
                .foregroundStyle(Palette.ink2)
                .piece(top: 16, left: 18, rotate: -7)
            DrawablyBadge("v0.4.2")
                .piece(top: 20, right: 14, rotate: 5)
            DrawablyCard {
                CodeBlock(code: """
                import Drawably

                DrawablyButton("Save", state: .loading)
                """)
            }
            .fixedSize(horizontal: wide, vertical: false)
            .frame(maxWidth: wide ? min(280, size.width * 0.7) : min(260, size.width - 40))
            .piece(right: 12, bottom: 14, rotate: -4)
        }
    }
}

// MARK: - API

struct ApiBoard: View {
    var size: CGSize

    var body: some View {
        Board(size: size) {
            DrawablyCard {
                CodeBlock(code: """
                import Drawably

                DrawablyButton("Done", variant: .solid, state: .success) { done() }
                """)
            }
            .frame(width: min(420, size.width * 0.86))
            .brandEntrance()
        } pieces: {
            fn("DrawablyButton", "title", "action").piece(top: 14, left: 18, rotate: -6)
            fn("DrawablyCheckbox", "isOn:").piece(top: 18, right: 11, rotate: 5)
            fn("DrawablyTextField", "text:").piece(left: 18, bottom: 20, rotate: 4)
            fn("DrawablyCard", "content").piece(right: 10, bottom: 16, rotate: -5)
            fn("DrawablyRadio", "value:", "selection:").piece(top: 8, left: 40, rotate: 4)
            fn("DrawablyToggle", "isOn:").piece(left: 38, bottom: 8, rotate: -3)
            fn("DrawablyDivider").piece(top: 48, left: 8, rotate: 5)
            fn(".drawablyArrow", "from:", "to:").piece(top: 34, right: 20, rotate: -3)
        }
    }

    /// `.fn` in a card: name, then arguments in amber between grey parens.
    private func fn(_ name: String, _ args: String...) -> some View {
        var s = AttributedString(name)
        s.foregroundColor = Palette.ink
        func add(_ t: String, _ c: Color) {
            var a = AttributedString(t)
            a.foregroundColor = c
            s += a
        }
        add("(", Palette.codeP)
        for (i, a) in args.enumerated() {
            if i > 0 { add(", ", Palette.codeP) }
            add(a, Palette.codeO)
        }
        add(")", Palette.codeP)
        return DrawablyCard { Text(s).font(.fn).tracking(0) }
    }
}

// MARK: - Compose

/// Not on drawably's page: the composites, drawn by the same port.
struct ComposeBoard: View {
    var size: CGSize
    @State private var pen = true
    @State private var marker = false
    @State private var tab = 0
    @State private var page = 1

    var body: some View {
        Board(size: size) {
            DrawablyCard {
                CodeBlock(code: """
                DrawablyTabs(selection: $tab) {
                    Text("pen"); Text("pencil"); Text("marker")
                }
                DrawablyTooltip("undo", to: "undo")
                """)
            }
            .frame(width: min(420, size.width * 0.86))
            .brandEntrance()
        } pieces: {
            HStack(spacing: 10) {
                DrawablyChip("pen", isOn: $pen)
                DrawablyChip("marker", isOn: $marker)
            }
            .piece(top: 14, left: 14, rotate: -5)
            DrawablyTabs(selection: $tab) {
                Text("pen")
                Text("pencil")
                Text("marker")
            }
            .piece(top: 12, right: 14, rotate: 4)
            DrawablyTooltip("undo", to: "undo")
                .piece(top: 32, left: 9, rotate: -3)
            DrawablyButton("Undo", tone: .neutral)
                .drawablyAnchor("undo")
                .piece(top: 44, left: 24, rotate: 5)
            DrawablyAlert(tag: "new") {
                Text("Import from Attio lands Friday").font(.drawablyInter(14))
            }
            .piece(left: 10, bottom: 18, rotate: 3)
            DrawablySteps(lineHeight: 21) {
                Text("record")
                Text("label")
                Text("ship")
            }
            .font(.drawablyInter(14))
            .foregroundStyle(Palette.ink2)
            .piece(top: 30, right: 12, rotate: -4)
            DrawablyKbd("⌘K")
                .piece(top: 58, right: 26, rotate: 6)
            DrawablyQuote(Text("less, but better")) {
                Text("Rams").font(.fn).foregroundStyle(Palette.ink2)
            }
            .piece(right: 12, bottom: 12, rotate: -3)
            DrawablyPager(page: $page, count: 3)
                .piece(left: 40, bottom: 7, rotate: 2)
            DrawablyBadge("scribble", variant: .scribble)
                .piece(top: 62, left: 30, rotate: -6)
            Text("Drawably Pen")
                .font(.drawablyPen(22))
                .foregroundStyle(Palette.pen)
                .piece(top: 8, left: 40, rotate: 3)
        }
    }
}
