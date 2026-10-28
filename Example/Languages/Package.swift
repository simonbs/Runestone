// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "Languages",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "RunestoneJavaScriptLanguage", targets: ["RunestoneJavaScriptLanguage"])
    ],
    dependencies: [
        .package(name: "Runestone", path: "../.."),
        .package(url: "https://github.com/simonbs/TreeSitterLanguages.git", branch: "codex/code-folding-queries")
    ],
    targets: [
        .target(
            name: "RunestoneJavaScriptLanguage",
            dependencies: [
                .product(name: "TreeSitterJavaScriptRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownRunestone", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownInlineRunestone", package: "TreeSitterLanguages")
            ],
            exclude: ["IndentationScopes.swift", "highlights.scm", "injections.scm"]
        )
    ]
)
