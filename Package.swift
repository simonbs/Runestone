// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "Runestone", targets: ["Runestone"])
    ],
    dependencies: [
        // Tree-sitter supports SPM but as of writing this, the official Tree-sitter repository has no versions published that contains the Package.swift file. Therefore, we depend on a fork of Tree-sitter that has a version published.
        // We will pin against the official version of Tree-sitter as soon as a new version is published.
        .package(url: "https://github.com/simonbs/tree-sitter", from: "0.20.9-beta.1")
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            .product(name: "TreeSitter", package: "tree-sitter")
        ], resources: [
            .process("TextView/Appearance/Theme.xcassets")
        ]),
        .target(name: "TestTreeSitterLanguages", cSettings: [
            .unsafeFlags(["-w"])
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone", 
            "TestTreeSitterLanguages"
        ])
    ]
)
