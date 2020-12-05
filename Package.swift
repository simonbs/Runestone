// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "Runestone",
            targets: ["Runestone"]),
    ],
    targets: [
        .target(
            name: "Runestone",
            dependencies: ["TreeSitterBindings", "TreeSitterJSON"]),
        .target(
            name: "TreeSitterBindings",
            dependencies: ["TreeSitter"]),
        .target(
            name: "TreeSitter",
            exclude: [
                "src",
                "unicode/ICU_SHA",
                "unicode/LICENSE",
                "unicode/README.md"
            ]),
        .target(name: "TreeSitterJSON"),
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone"]),
    ]
)
