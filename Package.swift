// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Harmonium",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HarmoniumCore"),
        .executableTarget(name: "Harmonium", dependencies: ["HarmoniumCore"]),
        .testTarget(name: "HarmoniumCoreTests", dependencies: ["HarmoniumCore"]),
    ]
)
