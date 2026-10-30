#!/bin/bash
# Test the actual engine sources independently of the UIKit-only Runestone target.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
harness_dir="$(mktemp -d "${TMPDIR:-/tmp}/runestone-engine-tests.XXXXXX")"
trap 'rm -rf "$harness_dir"' EXIT
ln -s "$repo_root/Sources/RunestoneEngine" "$harness_dir/Sources"
ln -s "$repo_root/Tests/RunestoneEngineTests" "$harness_dir/Tests"
cat > "$harness_dir/Package.swift" <<'MANIFEST'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "RunestoneEngineHarness",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "RunestoneEngine", path: "Sources"),
        .testTarget(name: "RunestoneEngineTests", dependencies: ["RunestoneEngine"], path: "Tests")
    ]
)
MANIFEST
swift test --package-path "$harness_dir" --scratch-path "$harness_dir/build" 2>&1 | xcsift -f toon
