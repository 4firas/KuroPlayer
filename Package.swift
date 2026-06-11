// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KuroPlayer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KuroPlayer",
            dependencies: [],
            path: "Sources/KuroPlayer"
        )
    ]
)
