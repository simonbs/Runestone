// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "Runestone", targets: ["Runestone"])
    ],
    dependencies: [
        // Tree-sitter supports SPM but as of writing this, the official Tree-sitter repository has no versions published that contains the Package.swift file. Therefore, we depend on a fork of Tree-sitter that has a version published.
        // We will pin against the official version of Tree-sitter as soon as a new version is published.
        .package(url: "https://github.com/simonbs/tree-sitter", from: "0.20.9-beta-1"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            "RunestoneMacros",
            "RunestoneObservation",
            .product(name: "TreeSitter", package: "tree-sitter")
        ], resources: [
            .process("Core/Theme/Theme.xcassets")
        ]),
//        .testTarget(name: "RunestoneTests", dependencies: [
//            "Runestone",
//            "TestTreeSitterLanguages"
//        ])
        .macro(name: "RunestoneMacros", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]),
        .testTarget(name: "RunestoneMacrosTests", dependencies: [
            "RunestoneMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ]),
//        .target(name: "TestTreeSitterLanguages", path: "Tests/TestTreeSitterLanguages", cSettings: [
//            .unsafeFlags(["-w"])
//        ]),
        .target(name: "RunestoneObservation", dependencies: [
            "RunestoneObservationMacros"
        ]),
        .testTarget(name: "RunestoneObservationTests", dependencies: [
            "RunestoneObservation"
        ]),
        .macro(name: "RunestoneObservationMacros", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]),
        .testTarget(name: "RunestoneObservationMacrosTests", dependencies: [
            "RunestoneObservationMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ])
    ]
)
