// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LanScanner",
    products: [
        .library(
            name: "LanScan",
            targets: ["LanScan"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LanScan",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LanScannerTests",
            dependencies: ["LanScan"]),
    ]
)
