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
        )
    ],
    targets: [
        .target(
            name: "WordBitesKit",
            resources: [
                .process("Resources/enable1.txt")
            ]
        ),
        .testTarget(
            name: "WordBitesKitTests",
            dependencies: ["WordBitesKit"]
        )
    ]
)
