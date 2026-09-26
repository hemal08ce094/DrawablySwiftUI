// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Drawably",
    platforms: [.iOS(.v18), .macOS(.v15), .visionOS(.v2)],
    products: [
        .library(name: "Drawably", targets: ["Drawably"]),
    ],
    targets: [
        .target(
            name: "Drawably",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DrawablyTests", dependencies: ["Drawably"]),
    ],
    swiftLanguageModes: [.v5]
)
