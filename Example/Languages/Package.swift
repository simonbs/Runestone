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
        .package(url: "https://github.com/simonbs/TreeSitterLanguages.git", revision: "12e38d632d845ba6e94eff02de53418963a98506")
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
