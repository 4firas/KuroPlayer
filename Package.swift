// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KuroPlayer",
    platforms: [
        .macOS(.v15)
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
