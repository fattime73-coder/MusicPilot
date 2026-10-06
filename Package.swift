// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MusicPilot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MusicPilot", targets: ["MusicPilot"])],
    targets: [
        .target(name: "MusicPilotCore"),
        .executableTarget(name: "MusicPilot", dependencies: ["MusicPilotCore"]),
        .testTarget(name: "MusicPilotCoreTests", dependencies: ["MusicPilotCore"])
    ],
    swiftLanguageModes: [.v5]
)
