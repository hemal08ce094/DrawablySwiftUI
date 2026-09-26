import Foundation
import SwiftUI
import Testing
@testable import Drawably

// Parity with the JS library: reference.json holds drawably 0.4.2's own path
// strings for the same shapes and seeds.

/// A Path in drawably's `toPath` notation, two decimals like `toFixed(2)`.
func svg(_ path: Path) -> String {
    func f(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
    var d = ""
    path.forEach { e in
        switch e {
        case .move(let p): d += "M\(f(p.x)) \(f(p.y))"
        case .line(let p): d += "L\(f(p.x)) \(f(p.y))"
        case .quadCurve(let p, let c): d += "Q\(f(c.x)) \(f(c.y)) \(f(p.x)) \(f(p.y))"
        case .curve: d += "C"
        case .closeSubpath: d += "Z"
        }
    }
    return d
}

func reference() throws -> [String: [String]] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("reference.json")
    return try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: url))
}

@Test func mulberryMatchesJavaScript() {
    var r = Mulberry32(42)
    #expect([r.next(), r.next(), r.next()] == [0.6011037519201636, 0.44829055899754167, 0.8524657934904099])
    var r2 = Mulberry32(4294967295)
    #expect([r2.next(), r2.next()] == [0.8964226141106337, 0.189478256739676])
}

@Test func shapesMatchJavaScript() throws {
    let ref = try reference()
    let o = RoughOptions(seed: 7)
    let shapes: [String: [Path]] = [
        "rect": Rough.variants(o) { Rough.roundedRect(3, 3, 94, 34, 8, $0) },
        "ellipse": Rough.variants(o) { Rough.ellipse(50, 20, 40, 18, $0) },
        "arrow": Rough.variants(o) { Rough.arrow(10, 10, 120, 60, $0) },
        "check": Rough.variants(o) { Rough.checkmark(5, 4, 11, 11, $0) },
        "scribble": Rough.variants(RoughOptions(seed: 4294967290)) { Rough.scribbleFill(5, 5, 80, 24, $0) },
    ]
    for (name, paths) in shapes {
        #expect(paths.map(svg) == ref[name], "\(name) differs from drawably")
    }
}
