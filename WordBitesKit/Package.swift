// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WordBitesKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WordBitesKit",
            targets: ["WordBitesKit"]
        ),
        .executable(
            name: "WordBitesCLI",
            targets: ["WordBitesCLI"]
        )
    ],
    targets: [
        .target(
            name: "WordBitesKit",
            resources: [
                .process("Resources/enable1.txt")
            ]
        ),
        .executableTarget(
            name: "WordBitesCLI",
            dependencies: ["WordBitesKit"]
        ),
        .testTarget(
            name: "WordBitesKitTests",
            dependencies: ["WordBitesKit"]
        )
    ]
)
