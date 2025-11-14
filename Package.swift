// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ARCStorage",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "ARCStorage",
            targets: ["ARCStorage"]
        ),
    ],
    targets: [
        .target(
            name: "ARCStorage",
            path: "Sources"
        ),
        .testTarget(
            name: "ARCStorageTests",
            dependencies: ["ARCStorage"],
            path: "Tests"
        )
    ]
)
