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
        .target(name: "Byte"),
        .target(name: "CharacterSetHelpers"),
        .target(name: "LineManager", dependencies: [
            "Byte",
            "RedBlackTree",
            "StringView",
            "Symbol"
        ]),
        .target(name: "RedBlackTree"),
        .target(name: "Runestone", dependencies: [
            "Byte",
            "CharacterSetHelpers",
            "LineManager",
            "MultiPlatform",
            "RangeHelpers",
            "StringHelpers",
            "StringView",
            "TreeSitter",
            "TreeSitterLib"
        ], resources: [
            .process("TextView/Appearance/Theme.xcassets")
        ]),
        .target(name: "MultiPlatform"),
        .target(name: "RangeHelpers"),
        .target(name: "StringHelpers", dependencies: [
            "CharacterSetHelpers",
            "Symbol"
        ]),
        .target(name: "StringView", dependencies: [
            "Byte",
            "StringHelpers"
        ]),
        .target(name: "Symbol"),
        .target(name: "TreeSitter", dependencies: [
            "Byte",
            "StringHelpers",
            "StringView",
            "TreeSitterLib"
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
        .testTarget(name: "ByteTests", dependencies: [
            "Byte"
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Byte",
            "LineManager",
            "Runestone",
            "StringView",
            "TestTreeSitterLanguages"
        ]),
        .testTarget(name: "StringViewTests", dependencies: [
            "Byte",
            "StringView"
        ]),
        .target(name: "TestTreeSitterLanguages", cSettings: [
            .unsafeFlags(["-w"])
        ])
    ]
)
