// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MetaLens",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MetaLensKit"),
        .executableTarget(name: "MetaLens", dependencies: ["MetaLensKit"]),
        .testTarget(name: "MetaLensKitTests", dependencies: ["MetaLensKit"]),
    ]
)
