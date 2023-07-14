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
    dependencies: [
        // Pins tree-sitter to the merge commit when SPM was added. This will be changed to pin to a release, when a release is created that includes SPM.
        .package(url: "https://github.com/tree-sitter/tree-sitter", .revision("9fd128ed604bb63348281bd4ac0d99705e713147"))
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            .product(name: "TreeSitter", package: "tree-sitter")
        ], resources: [.process("TextView/Appearance/Theme.xcassets")]),
        .target(name: "TestTreeSitterLanguages", cSettings: [.unsafeFlags(["-w"])]),
        .testTarget(name: "RunestoneTests", dependencies: ["Runestone", "TestTreeSitterLanguages"])
    ]
)
