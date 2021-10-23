// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LanScanner",
    products: [
        .library(
            name: "LanScanner",
            targets: ["LanScanner"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LanScanner",
            dependencies: ["LanScanInternal"]
        ),
        .target(
            name: "LanScanInternal",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LanScannerTests",
            dependencies: []),
    ]
)
