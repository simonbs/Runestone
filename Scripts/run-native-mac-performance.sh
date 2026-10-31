#!/bin/bash
# Run serial Release measurements for the native AppKit/Core Text document view.
# Set RUNESTONE_MAC_PERFORMANCE_SCENARIO to one printed scenario name for a
# focused diagnostic; omitting it runs the five-scenario representative matrix.
set -euo pipefail

results="${1:-$(mktemp -d /tmp/runestone-mac-performance.XXXXXX)}"
mkdir -p "$results"
results="$(cd "$results" && pwd)"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
command -v xcsift >/dev/null

{
    sw_vers
    sysctl -n hw.model hw.memsize machdep.cpu.brand_string
    xcodebuild -version
    swift --version
} > "$results/system.txt" 2>&1

# The main package also contains the UIKit-only Runestone target. Build the same
# isolated macOS harness as test-engine-macos.sh so this lane exercises only the
# shared engine and native AppKit product.
harness="$results/Harness"
mkdir -p "$harness/Sources" "$harness/Tests"
ln -s "$repo_root/Sources/RunestoneEngine" "$harness/Sources/RunestoneEngine"
ln -s "$repo_root/Sources/RunestoneAppKit" "$harness/Sources/RunestoneAppKit"
ln -s "$repo_root/Tests/RunestoneAppKitTests" "$harness/Tests/RunestoneAppKitTests"
cat > "$harness/Package.swift" <<'MANIFEST'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "RunestoneMacPerformanceHarness",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "RunestoneEngine"),
        .target(name: "RunestoneAppKit", dependencies: ["RunestoneEngine"]),
        .testTarget(name: "RunestoneAppKitTests", dependencies: ["RunestoneAppKit", "RunestoneEngine"])
    ]
)
MANIFEST

set -o pipefail
RUNESTONE_MAC_PERFORMANCE=1 swift test --package-path "$harness" --scratch-path "$harness/build" -c release \
    --filter NativeMacPerformanceBaselineTests/testRepresentativeAppKitScenarios \
    2>&1 | tee "$results/measurements.log" | xcsift -f toon -w

echo "Measurements and raw samples: $results/measurements.log"
echo "Measurement host: $results/system.txt"
