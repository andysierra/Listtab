// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ListTab",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ListTab", path: "Sources/ListTab")
    ]
)
