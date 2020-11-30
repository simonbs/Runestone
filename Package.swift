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
            dependencies: ["OnigurumaBindings"]),
//        .target(
//            name: "Runestone",
//            dependencies: ["RunestoneTextStorage"]),
//        .target(
//            name: "RunestoneTextStorage",
//            dependencies: []),
        .target(
            name: "OnigurumaBindings",
            dependencies: ["Oniguruma"]),
        .target(
            name: "Oniguruma",
            exclude: ["COPYING"]),
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone"]),
    ]
)
