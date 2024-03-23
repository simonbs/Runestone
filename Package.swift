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
        // Tree-sitter supports SPM but as of writing this, the official Tree-sitter repository
        // has no versions published that contains the Package.swift file. Therefore, we depend
        // on a fork of Tree-sitter that has a version published. We will pin against the official
        // version of Tree-sitter as soon as a new version is published.
        .package(url: "https://github.com/tree-sitter/tree-sitter", .upToNextMinor(from: "0.20.9")),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        // Public
        .target(name: "Runestone", dependencies: [
            "_RunestoneMacros",
            "_RunestoneMultiPlatform",
            "_RunestoneObservation",
            "_RunestoneRedBlackTree",
            "_RunestoneTreeSitter"
        ], resources: [
            .process("Core/Theme/Theme.xcassets")
        ]),

        // Private
        .privateTarget(name: "_RunestoneMultiPlatform"),
        .privateTarget(name: "_RunestoneObservation", dependencies: [
            "_RunestoneMacros"
        ]),
        .privateTarget(name: "_RunestoneProxy", dependencies: [
            "_RunestoneMacros"
        ]),
        .privateTarget(name: "_RunestoneRedBlackTree"),
        .privateTarget(name: "_RunestoneStringUtilities"),
        .privateTarget(name: "_RunestoneTreeSitter", dependencies: [
            "_RunestoneStringUtilities",
            .product(name: "TreeSitter", package: "tree-sitter")
        ]),

        // Macros
        .privateMacro(name: "_RunestoneMacros", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]),

        // Tests
        .target(name: "_TestTreeSitterLanguages", path: "Tests/TestTreeSitterLanguages", cSettings: [
            .unsafeFlags(["-w"])
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone",
            "_TestTreeSitterLanguages"
        ]),
        .testTarget(name: "RunestoneObservationTests", dependencies: [
            "_RunestoneObservation"
        ]),
        .testTarget(name: "RunestoneMacrosTests", dependencies: [
            "_RunestoneMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ])
    ]
)

private extension Target {
    static func privateTarget(name: String, dependencies: [Target.Dependency] = []) -> Target {
        .target(name: name, dependencies: dependencies, path: "Sources/Private/" + name.drop { $0 == "_" })
    }

    static func privateMacro(name: String, dependencies: [Target.Dependency] = []) -> Target {
        .macro(name: name, dependencies: dependencies, path: "Sources/Private/" + name.drop { $0 == "_" })
    }
}
