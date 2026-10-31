#!/bin/bash
# Test the engine and AppKit adapter independently of the UIKit-only Runestone target.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
harness_dir="$(mktemp -d "${TMPDIR:-/tmp}/runestone-engine-tests.XXXXXX")"
trap 'rm -rf "$harness_dir"' EXIT
mkdir -p "$harness_dir/Sources" "$harness_dir/Tests"
ln -s "$repo_root/Sources/RunestoneEngine" "$harness_dir/Sources/RunestoneEngine"
ln -s "$repo_root/Sources/RunestoneSyntax" "$harness_dir/Sources/RunestoneSyntax"
ln -s "$repo_root/Sources/RunestoneAppKit" "$harness_dir/Sources/RunestoneAppKit"
ln -s "$repo_root/tree-sitter/lib" "$harness_dir/Sources/TreeSitter"
ln -s "$repo_root/Sources/TestTreeSitterLanguages" "$harness_dir/Sources/TestTreeSitterLanguages"
ln -s "$repo_root/Tests/RunestoneEngineTests" "$harness_dir/Tests/RunestoneEngineTests"
ln -s "$repo_root/Tests/RunestoneSyntaxTests" "$harness_dir/Tests/RunestoneSyntaxTests"
ln -s "$repo_root/Tests/RunestoneAppKitTests" "$harness_dir/Tests/RunestoneAppKitTests"
cat > "$harness_dir/Package.swift" <<'MANIFEST'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "RunestoneEngineHarness",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "RunestoneEngine"),
        .target(name: "TreeSitter", path: "Sources/TreeSitter", sources: ["src/lib.c"],
                publicHeadersPath: "include",
                cSettings: [.headerSearchPath("src"), .define("_DARWIN_C_SOURCE")]),
        .target(name: "TestTreeSitterLanguages", cSettings: [.headerSearchPath("private"), .unsafeFlags(["-w"])]),
        .target(name: "RunestoneSyntax", dependencies: ["RunestoneEngine", "TreeSitter"]),
        .target(name: "RunestoneAppKit", dependencies: ["RunestoneEngine", "RunestoneSyntax"]),
        .testTarget(name: "RunestoneEngineTests", dependencies: ["RunestoneEngine"]),
        .testTarget(name: "RunestoneSyntaxTests", dependencies: ["RunestoneSyntax", "TestTreeSitterLanguages"]),
        .testTarget(name: "RunestoneAppKitTests", dependencies: ["RunestoneAppKit", "RunestoneEngine"])
    ]
)
MANIFEST
swift test --package-path "$harness_dir" --scratch-path "$harness_dir/build" "$@" 2>&1 | xcsift -f toon
