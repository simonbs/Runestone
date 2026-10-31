#!/usr/bin/env bash
# Build and run the public-attachment foreground acceptance tests in an
# isolated AppKit test runner. This repository is a library, not an app.
set -euo pipefail

case "${1:-run}" in
  run|--verify|verify) ;;
  *) printf 'usage: %s [run|--verify]\n' "$0" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  printf 'usage: %s [run|--verify]\n' "$0" >&2
  exit 2
fi
command -v xcsift >/dev/null || { echo 'xcsift is required.' >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ARTIFACT_DIR="$(mktemp -d /private/tmp/runestone-live.XXXXXXXX)"
PACKAGE_DIR="$ARTIFACT_DIR/package"
BUILD_DIR="$ARTIFACT_DIR/build"
CACHE_DIR="$ARTIFACT_DIR/cache"
APP_BUNDLE="$ARTIFACT_DIR/RunestoneLiveTests.app"
STDOUT_LOG="$ARTIFACT_DIR/runner.stdout.log"
STDERR_LOG="$ARTIFACT_DIR/runner.stderr.log"
BUILD_LOG="$ARTIFACT_DIR/build.log"
trap 'printf "Live acceptance artifacts: %s\n" "$ARTIFACT_DIR"' EXIT
printf 'Live acceptance artifacts: %s\n' "$ARTIFACT_DIR"

mkdir -p "$PACKAGE_DIR/Sources" "$PACKAGE_DIR/Tests" "$CACHE_DIR"
ln -s "$ROOT_DIR/Sources/RunestoneEngine" "$PACKAGE_DIR/Sources/RunestoneEngine"
ln -s "$ROOT_DIR/Sources/RunestoneAppKit" "$PACKAGE_DIR/Sources/RunestoneAppKit"
ln -s "$ROOT_DIR/Tests/RunestoneAppKitTests" "$PACKAGE_DIR/Tests/RunestoneAppKitTests"
cat > "$PACKAGE_DIR/Package.swift" <<'SWIFT'
// swift-tools-version:5.5
import PackageDescription
let package = Package(name: "RunestoneLiveHarness", platforms: [.macOS("26.0")], targets: [
    .target(name: "RunestoneEngine"),
    .target(name: "RunestoneAppKit", dependencies: ["RunestoneEngine"]),
    .testTarget(name: "RunestoneAppKitTests", dependencies: ["RunestoneAppKit", "RunestoneEngine"])
])
SWIFT

# The xcsift pipeline uses pipefail so a build error cannot be hidden by tee.
(
  cd "$PACKAGE_DIR"
  SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_DIR" swift build --build-tests \
    --scratch-path "$BUILD_DIR" --cache-path "$CACHE_DIR" 2>&1 | tee "$BUILD_LOG" | xcsift -f toon -w
)

XCTEST_RUNNER="$(xcrun --find xctest)"
DEVELOPER_DIR_SELECTED="$(cd "$(dirname "$XCTEST_RUNNER")/../.." && pwd -P)"
XCTEST_FRAMEWORK="$DEVELOPER_DIR_SELECTED/Platforms/MacOSX.platform/Developer/Library/Frameworks/XCTest.framework"
XCTEST_SWIFT_SUPPORT="$DEVELOPER_DIR_SELECTED/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestSwiftSupport.dylib"
PRODUCT_DIR="$BUILD_DIR/debug"
TEST_BUNDLE="$PRODUCT_DIR/RunestoneAppKitTests.xctest"
[[ -x "$XCTEST_RUNNER" && -d "$XCTEST_FRAMEWORK" && -f "$XCTEST_SWIFT_SUPPORT" && -d "$TEST_BUNDLE" ]] || {
  echo 'The selected Xcode toolchain or the built XCTest bundle is incomplete.' >&2
  exit 1
}
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Frameworks" "$PRODUCT_DIR/PackageFrameworks"
cp "$XCTEST_RUNNER" "$APP_BUNDLE/Contents/MacOS/RunestoneLiveTests"
ln -s "$XCTEST_FRAMEWORK" "$APP_BUNDLE/Frameworks/XCTest.framework"
ln -s "$XCTEST_SWIFT_SUPPORT" "$PRODUCT_DIR/PackageFrameworks/libXCTestSwiftSupport.dylib"
RUN_ID="${ARTIFACT_DIR##*.}"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>RunestoneLiveTests</string>
<key>CFBundleIdentifier</key><string>dk.simonbs.runestone.LiveAcceptance.$RUN_ID</string>
<key>CFBundleName</key><string>Runestone Live Acceptance</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
: > "$STDOUT_LOG"
: > "$STDERR_LOG"
FILTER='RunestoneAppKitTests.PublicAttachmentLiveKeyTests,RunestoneAppKitTests.PublicAttachmentLiveAccessibilityTests,RunestoneAppKitTests.PublicAttachmentLiveInteractionTests'

# `open -W` does not reliably propagate XCTest failures. Give the foreground
# runner a finite deadline and inspect the XCTest log below. If it hangs, stop
# only the executable in this invocation's unique temporary app bundle.
python3 - "$APP_BUNDLE" "$STDOUT_LOG" "$STDERR_LOG" "$FILTER" "$TEST_BUNDLE" <<'PY'
import os
import signal
import subprocess
import sys

app, stdout, stderr, test_filter, bundle = sys.argv[1:]
command = ["/usr/bin/open", "-n", "-W", "--stdout", stdout, "--stderr", stderr,
           app, "--args", "-XCTest", test_filter, bundle]
process = subprocess.Popen(command)
try:
    code = process.wait(timeout=180)
except subprocess.TimeoutExpired:
    executable = app + "/Contents/MacOS/RunestoneLiveTests"
    processes = subprocess.run(["/bin/ps", "-axo", "pid=,command="], text=True,
                               capture_output=True, check=False).stdout
    for line in processes.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and (parts[1] == executable or parts[1].startswith(executable + " ")):
            try:
                os.kill(int(parts[0]), signal.SIGTERM)
            except ProcessLookupError:
                pass
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    print("Foreground test runner exceeded 180 seconds; stopped this invocation's runner.", file=sys.stderr)
    sys.exit(124)
if code:
    print(f"Could not launch or wait for the foreground test runner (open exited {code}).", file=sys.stderr)
    sys.exit(code)
PY

# Format the raw XCTest output as well; the strict case-by-case check below
# remains authoritative because `open` can return success after test failure.
cat "$STDERR_LOG" "$STDOUT_LOG" | xcsift -f toon -w

# Verify the actual selected cases, not just the launch status or total count.
# Checking each declared XCTest method also detects a missing suite or filter.
python3 - "$ROOT_DIR" "$STDOUT_LOG" "$STDERR_LOG" <<'PY'
from pathlib import Path
import re
import sys

root, stdout, stderr = map(Path, sys.argv[1:])
suites = ["PublicAttachmentLiveKeyTests", "PublicAttachmentLiveAccessibilityTests",
          "PublicAttachmentLiveInteractionTests"]
expected = set()
for suite in suites:
    source = root / "Tests" / "RunestoneAppKitTests" / (suite + ".swift")
    if not source.is_file():
        sys.exit(f"Required acceptance test file is missing: {source}")
    text = source.read_text()
    if not re.search(r"\bclass\s+" + re.escape(suite) + r"\s*:\s*XCTestCase\b", text):
        sys.exit(f"Required acceptance test suite is missing: {suite}")
    names = re.findall(r"^\s*func\s+(test\w+)\s*\(", text, flags=re.MULTILINE)
    if not names:
        sys.exit(f"Required acceptance test suite has no test methods: {suite}")
    expected.update((suite, name) for name in names)
log = stderr.read_text(errors="replace") + "\n" + stdout.read_text(errors="replace")
pattern = re.compile(r"Test Case '-\[RunestoneAppKitTests\.(\w+) (\w+)\]' (passed|failed|skipped)\b")
results = {}
for suite, name, status in pattern.findall(log):
    if suite in suites:
        results.setdefault((suite, name), []).append(status)
bad = sorted((case, results.get(case, [])) for case in expected if results.get(case) != ["passed"])
if bad or "Test Suite 'Selected tests' passed" not in log:
    for (suite, name), statuses in bad:
        print(f"{suite}.{name}: {statuses or ['not executed']}", file=sys.stderr)
    print("Foreground acceptance tests failed, skipped, did not finish, or did not all execute.", file=sys.stderr)
    print(f"Inspect {stderr} and {stdout}", file=sys.stderr)
    sys.exit(1)
print(f"Foreground acceptance passed: {len(expected)} tests across {len(suites)} suites.")
print(f"XCTest log: {stderr}")
PY
