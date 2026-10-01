// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacVitals",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacVitals",
            path: "Sources/MacVitals",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
