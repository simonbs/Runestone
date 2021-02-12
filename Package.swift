// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
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
            dependencies: ["RunestoneTreeSitter", "RunestoneUtils"]),
        .target(
            name: "RunestoneTreeSitter",
            dependencies: ["RunestoneUtils", "TreeSitter"]),
        .target(name: "RunestoneUtils"),
        .target(
            name: "TreeSitter",
            exclude: [
                "src",
                "unicode/ICU_SHA",
                "unicode/LICENSE",
                "unicode/README.md"
            ]),
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone"]),
    ]
)
