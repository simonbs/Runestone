// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS("26.0")
    ],
    products: [
        .library(name: "Runestone", targets: ["Runestone"]),
        .library(name: "RunestoneEngine", targets: ["RunestoneEngine"]),
        .library(name: "RunestoneAppKit", targets: ["RunestoneAppKit"]),
        .library(name: "TreeSitter", targets: ["TreeSitter"])
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            "TreeSitter",
            "RunestoneEngine"
        ], resources: [
            .copy("PrivacyInfo.xcprivacy"),
            .process("TextView/Appearance/Theme.xcassets")
        ]),
        .target(name: "RunestoneEngine"),
        .target(name: "RunestoneAppKit", dependencies: ["RunestoneEngine"]),
        .target(
            name: "TreeSitter",
            path: "tree-sitter/lib",
            sources: ["src/lib.c"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("src"), .define("_DARWIN_C_SOURCE")]
        ),
        .target(name: "TestTreeSitterLanguages", cSettings: [
            .headerSearchPath("private"),
            .unsafeFlags(["-w"])
        ]),
        .testTarget(name: "RunestoneEngineTests", dependencies: ["RunestoneEngine"]),
        .testTarget(name: "RunestoneAppKitTests", dependencies: ["RunestoneAppKit", "RunestoneEngine"]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone",
            "TestTreeSitterLanguages"
        ])
    ],
    cLanguageStandard: .c11
)
