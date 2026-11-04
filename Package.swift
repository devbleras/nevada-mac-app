// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nevada",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nevada",
            path: "Sources/Nevada",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
