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
    targets: [
        .target(name: "Runestone", dependencies: ["TreeSitter"]),
        .target(name: "TreeSitter",
                path: "tree-sitter/lib",
                exclude: [
                    "binding_rust",
                    "binding_web",
                    "Cargo.toml",
                    "README.md",
                    "src/unicode/README.md",
                    "src/unicode/LICENSE",
                    "src/unicode/ICU_SHA",
                    "src/get_changed_ranges.c",
                    "src/tree_cursor.c",
                    "src/stack.c",
                    "src/node.c",
                    "src/lexer.c",
                    "src/parser.c",
                    "src/language.c",
                    "src/alloc.c",
                    "src/subtree.c",
                    "src/tree.c",
                    "src/query.c"
                ],
                sources: ["src/lib.c"]),
        .target(name: "TestTreeSitterLanguages", cSettings: [.unsafeFlags(["-w"])]),
        .testTarget(name: "RunestoneTests", dependencies: ["Runestone", "TestTreeSitterLanguages"])
    ]
)
