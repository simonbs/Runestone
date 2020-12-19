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
            dependencies: ["RunestoneTextStorage"]),
        .target(
            name: "RunestoneTextStorage",
            dependencies: ["RunestoneDocumentLineTree", "RunestoneHighlighter"]),
        .target(name: "RunestoneDocumentLineTree"),
        .target(
            name: "RunestoneHighlighter",
            dependencies: ["TreeSitterBindings", "TreeSitterLanguages"],
            resources: [
                .copy("queries")
            ]),
        .target(name: "TreeSitterLanguages"),
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
        .testTarget(
            name: "RunestoneTests",
            dependencies: ["Runestone"]),
    ]
)
