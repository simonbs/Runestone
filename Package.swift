// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "Runestone", targets: ["Runestone"])
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            "TreeSitterLib"
        ], resources: [
            .process("Core/Theme/Theme.xcassets")
        ]),
        .target(name: "TreeSitterLib", path: "tree-sitter/lib", exclude: [
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
        ], sources: [
            "src/lib.c"
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone",
            "TestTreeSitterLanguages"
        ]),
        .target(name: "TestTreeSitterLanguages", path: "Tests/TestTreeSitterLanguages", cSettings: [
            .unsafeFlags(["-w"])
        ])
    ]
)
