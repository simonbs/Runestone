#!/bin/bash
# Run serial Release benchmarks on an existing simulator. Results stay outside the repo.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 SIMULATOR_UDID [RESULT_DIRECTORY] [TEST_IDENTIFIER ...]" >&2
    exit 1
fi
device="$1"
shift
results="${1:-$(mktemp -d /tmp/runestone-performance.XXXXXX)}"
if [[ $# -gt 0 ]]; then shift; fi
mkdir -p "$results"
results="$(cd "$results" && pwd)"
cd "$(dirname "$0")/.."
command -v xcsift >/dev/null

xcodebuild build-for-testing -scheme Runestone-Package -configuration Release -enableCodeCoverage NO \
    -destination "platform=iOS Simulator,id=$device" \
    -derivedDataPath "$results/DerivedData" ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$results/build.log" | xcsift -f toon

# Test runner variables are separate from xcodebuild's process environment.
test_run="$(python3 - "$results/DerivedData/Build/Products" <<'PY'
import glob
import os
import plistlib
import sys

paths = glob.glob(os.path.join(sys.argv[1], 'Runestone-Package*.xctestrun'))
if len(paths) != 1:
    raise SystemExit('Expected exactly one package xctestrun file')
path = paths[0]
with open(path, 'rb') as source:
    plan = plistlib.load(source)
for configuration in plan['TestConfigurations']:
    for target in configuration['TestTargets']:
        target.setdefault('EnvironmentVariables', {})['RUNESTONE_PERFORMANCE'] = '1'
with open(path, 'wb') as destination:
    plistlib.dump(plan, destination)
print(path)
PY
)"

if [[ $# -eq 0 ]]; then
    set -- RunestoneTests/LargeFilePerformanceTests RunestoneTests/PureASCIIEditorPerformanceTests \
        RunestoneTests/LongLinePreparationPerformanceTests \
        RunestoneTests/LargeFileTraversalTests RunestoneTests/LargeFileCorrectnessTests \
        RunestoneTests/LineBreakingPerformanceTests RunestoneTests/LineManagerPerformanceTests
fi
selections=()
for identifier in "$@"; do selections+=("-only-testing:$identifier"); done
xcodebuild test-without-building -xctestrun "$test_run" \
    -destination "platform=iOS Simulator,id=$device" -parallel-testing-enabled NO \
    -resultBundlePath "$results/Measurements.xcresult" "${selections[@]}" \
    2>&1 | tee "$results/measurements.log" | xcsift -f toon
echo "Measurements and raw samples: $results/measurements.log"
