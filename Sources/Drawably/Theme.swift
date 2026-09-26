import CoreText
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

/// The `--drawably-*` custom properties as a SwiftUI environment value.
public struct DrawablyTheme {
    public var stroke = Color(hex: 0x2724d1)
    public var fill = Color(hex: 0x2724d1)
    public var paper = Color.white
    /// Stroke width. `nil` keeps drawably's defaults: 2 on controls, 1.5 on text decorations.
    public var width: CGFloat?
    public var error = Color(hex: 0xd12724)
    public var success = Color(hex: 0x188a42)
    public var neutral = Color(hex: 0x6e675f)
    public var placeholder = Color(hex: 0xa1a1aa)
    public var roughness: Double = 1
    public var boil: Double = 0.3
    /// Control type. drawably uses Inter, falling back to the system face.
    public var font: Font = .drawablyInter(15)
    /// Badge / kbd type (Geist Mono in drawably).
    public var monoSize: CGFloat = 12

    public init() {}
}

extension EnvironmentValues {
    @Entry public var drawablyTheme = DrawablyTheme()
    /// Set by state styles (error/success) to override stroke and fill together, like `--drawably-ink`.
    @Entry var drawablyInk: Color? = nil
}

public extension View {
    /// Theme every drawably control below this view.
    func drawablyTheme(_ update: @escaping (inout DrawablyTheme) -> Void) -> some View {
        transformEnvironment(\.drawablyTheme, transform: update)
    }

    /// Set the common theme values, the way you would set the `--drawably-*` custom properties.
    func drawably(
        stroke: Color? = nil, fill: Color? = nil, paper: Color? = nil, width: CGFloat? = nil,
        roughness: Double? = nil, boil: Double? = nil
    ) -> some View {
        drawablyTheme { t in
            if let stroke { t.stroke = stroke }
            if let fill { t.fill = fill }
            if let paper { t.paper = paper }
            if let width { t.width = width }
            if let roughness { t.roughness = roughness }
            if let boil { t.boil = boil }
        }
    }
}

// MARK: - Fonts

enum DrawablyFonts {
    static let registered: Void = {
        for name in ["Inter", "GeistMono", "DrawablyPen"] {
            if let url = resourceBundle.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }
}

private final class BundleToken {}

public extension Font {
    /// Inter, bundled with the package.
    static func drawablyInter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = DrawablyFonts.registered
        return .custom("Inter", size: size).weight(weight)
    }

    /// Geist Mono, bundled with the package.
    static func drawablyMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = DrawablyFonts.registered
        return .custom("Geist Mono", size: size).weight(weight)
    }

    /// Drawably Pen: the library's own strokes as a typeface. Opt in, like `drawably/font.css`.
    static func drawablyPen(_ size: CGFloat) -> Font {
        _ = DrawablyFonts.registered
        return .custom("Drawably Pen", size: size)
    }
}
