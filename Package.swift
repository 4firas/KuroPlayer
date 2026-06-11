// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KuroPlayer",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KuroPlayer",
            dependencies: [],
            path: "Sources/KuroPlayer"
        ),
        .testTarget(
            name: "KuroPlayerTests",
            dependencies: ["KuroPlayer"],
            path: "Tests/KuroPlayerTests"
        )
    ]
)
