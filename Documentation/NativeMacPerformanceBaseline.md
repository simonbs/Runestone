# Native Mac performance baseline

This document records the first reproducible Release measurements for
Runestone's native AppKit/Core Text document surface. They are machine-specific
observations, not release budgets or pass/fail tolerances. A later product-level
performance decision must set tolerances from representative machines and
interactive traces rather than turning these numbers into arbitrary assertions.

## Harness and scope

Run `Scripts/run-native-mac-performance.sh [RESULT_DIRECTORY]`. The script builds
an isolated SwiftPM harness in Release configuration because the main package
also contains the UIKit-only `Runestone` target. The opt-in XCTest prints one
`RUNESTONE_MAC_PERFORMANCE_RESULT` JSON record per scenario, including all raw
samples. Set `RUNESTONE_MAC_PERFORMANCE_SCENARIO` to one printed scenario name for
a focused diagnostic.

Each trial constructs `ReadOnlyDocumentView`, attaches it to a 700×480 native
scroll view, performs first-viewport layout, then traverses middle, end, start and
end again. Fixture creation is outside the samples. The first trial is discarded;
the table reports the median of the next three. Load includes the view's
attributed-snapshot copy, line indexing and first viewport. Traversal includes
viewport layout, not display-server presentation. Resident memory is an
observation of the process at the load/traversal boundaries, not a peak or an
allocation attribution.

The highlighted fixture supplies 20,000 pre-highlighted attributed lines. This
measures highlighted Core Text rendering but deliberately does not claim
Tree-sitter parse/highlight latency: `RunestoneAppKit` does not link that UIKit
pipeline. The folded fixture applies the real engine collapsed-line projection,
hiding rows 1 through 18,000 of 20,001 logical lines and verifying the projection
and reduced document height.

## Baseline checkpoint

Measured on 2026-10-31 with macOS 27.0.1 (26A434), Xcode 27.2 (27B48), Swift
6.4.2, MacBookPro18,1, Apple M1 Pro and 32 GiB memory. The final serial Release
run passed with zero errors, warnings or test failures in 328.991 seconds. Raw
samples are in `/tmp/runestone-mac-baseline-final/measurements.log` on the
measurement host.

| Scenario | Fixture | Load median | Traversal median | Resident observation median |
| --- | ---: | ---: | ---: | ---: |
| Small | 200 lines / 9,600 UTF-8 bytes | 3.638 ms | 9.860 ms | 41.69 MiB |
| Large short lines | 10,001 lines / 10,000,000 bytes | 38.153 ms | 3.799 ms | 94.58 MiB |
| One long wrapped line | 1,096,249 UTF-16 units | 38.511 ms | 80,478.675 ms | 82.91 MiB |
| Pre-highlighted | 20,001 lines / 960,000 bytes | 36.417 ms | 15.382 ms | 70.95 MiB |
| Folded | 20,001 logical lines / 18,000 hidden rows | 37.167 ms | 16.751 ms | 72.28 MiB |

The first run exposed a long-wrapped-line defect rather than an acceptable
baseline. Its three traversal samples were 84,069.333 ms, 80,478.675 ms and
79,930.211 ms. A five-second process sample attributed 2,993 of 2,996 main-thread
samples to repeated `CTTypesetterSuggestLineBreak` calls through ICU while seeking
incrementally through the one logical line.

The repaired AppKit path conservatively admits only long printable-ASCII text
with supported editor attributes. Core Text still measures every fragment, while
a cluster-width query bounds a local native word-break window. Unicode, controls,
bidi text, paragraph styles and unsupported attributes retain the original native
paragraph path. Compatibility tests compare complete fragment ranges, hidden
whitespace, dimensions and vertical positions with that original path.

The unchanged five-scenario Release matrix after the repair passes in 1.896
seconds. The long-line traversal median is 122.674 ms (124.451, 121.955 and
122.674 ms), about 656× faster than 80,478.675 ms; its load median is 38.563 ms.
The same document height and 1,096,249-unit final visible range are preserved.
The other four latency medians remain within ordinary run-to-run variation:

| Scenario | Load median after repair | Traversal median after repair |
| --- | ---: | ---: |
| Small | 3.405 ms | 9.238 ms |
| Large short lines | 36.561 ms | 3.800 ms |
| One long wrapped line | 38.563 ms | 122.674 ms |
| Pre-highlighted | 35.303 ms | 14.970 ms |
| Folded | 36.171 ms | 16.306 ms |

The pre-repair results remain the evidence that caught the regression class; do
not reduce the fixture, skip deep traversal or replace the mechanism guard with a
large tolerance.

## Evidence limits and next work

This lane closes the missing repeatable Mac measurement matrix for small, large,
wrapped, attributed-highlighted and folded engine scenarios. It does not yet
measure app decoding/file I/O, editable attachment reconstruction, syntax parsing,
window-server frame delivery, interactive typing/selection, preview, printing,
restoration, IME, VoiceOver, energy or true peak memory. It also does not exercise
Intel/Rosetta performance.

Next performance work should profile and bound seeking within a very long wrapped
logical line without replacing the scenario with shorter lines. After that,
capture product-level interactive traces in the RunestoneEditor app and agree
latency/memory tolerances across representative hardware before adding gates.
