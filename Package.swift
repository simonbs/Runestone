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
        .library(name: "Runestone", targets: ["Runestone"]),
        .library(name: "TreeSitter", targets: ["TreeSitter"])
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            "TreeSitter"
        ], resources: [
            .copy("PrivacyInfo.xcprivacy"),
            .process("TextView/Appearance/Theme.xcassets")
        ]),
        .target(
            name: "TreeSitter",
            exclude: ["LICENSE", "README.md"],
            sources: ["src/lib.c"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("src"), .define("_DARWIN_C_SOURCE")]
        ),
        .target(name: "TestTreeSitterLanguages", cSettings: [
            .headerSearchPath("private"),
            .unsafeFlags(["-w"])
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone",
            "TestTreeSitterLanguages"
        ])
    ],
    cLanguageStandard: .c11
)
