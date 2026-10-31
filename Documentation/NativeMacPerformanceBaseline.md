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

The view lane constructs `ReadOnlyDocumentView`, attaches it to a 700×480 native
scroll view, performs first-viewport layout, then traverses middle, end, start and
end again. The syntax lane uses the real `RunestoneSyntaxHighlighter` and
Tree-sitter JavaScript grammar to measure full-snapshot parsing, a bounded 65,536
UTF-16-unit visible capture query, a whole-document fold query, incremental tree
reuse and superseded-update cancellation. Fixture construction is outside the
samples. The first trial is discarded; tables report the median of the next
three. Resident memory is an observation at sample boundaries, not a peak or an
allocation attribution.

The original highlighted fixture still supplies 20,000 pre-highlighted
attributed lines and measures Core Text presentation independently. The syntax
lane now measures the platform-neutral parser/highlighter introduced for AppKit.
The original folded fixture applies the engine collapsed-line projection; the
syntax folding scenario separately queries 20,000 real Tree-sitter fold ranges.

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

## Syntax, highlighting and folding refresh

Measured on the same host configuration on 2026-10-31 at framework revision
`6a7c0ef2`. The final serial Release run passed both opt-in tests with zero
failures and the three known Tree-sitter C integer-precision warnings. Raw
samples are retained at
`/tmp/runestone-syntax-baseline-final-3/measurements.log` on the measurement host.

| Syntax scenario | Fixture | Parse median | Bounded capture median | Whole-document fold median | Resident observation median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Small | 200 lines / 10,200 bytes | 0.461 ms | 0.249 ms | 0.214 ms | 112.69 MiB |
| Large short lines | 10,000,000 bytes | 439.028 ms | 2.138 ms | 226.700 ms | 258.33 MiB |
| One long logical line | 1,096,016 UTF-16 units | 99.351 ms | 50.776 ms | 50.279 ms | 310.86 MiB |
| Highlighted | 20,000 lines / 1,020,000 bytes | 41.648 ms | 1.541 ms | 18.600 ms | 327.69 MiB |
| Folded | 20,000 functions / 697,780 bytes | 49.705 ms | 2.626 ms | 25.021 ms | 329.20 MiB |
| Incremental edit | 20,000 lines / 1,020,000 bytes | 43.415 ms initial | 1.638 ms | 19.194 ms | 332.30 MiB |

The three incremental one-character update samples were 34.484 ms, 34.160 ms
and 35.448 ms. The folded scenario produced exactly 20,000 fold ranges. The
10 MB fold query deliberately remains whole-document work; its 226.700 ms median
is recorded rather than hidden behind the bounded visible-capture query.

Superseding a 10 MB parse with a tiny newest generation completed cancellation
and newest publication in 0.554 ms, 107.904 ms and 1.207 ms. The variation is
expected: the serial operation can be cancelled before it starts or after native
Tree-sitter work has begun. Every trial published only the newest generation;
these observations are not an invented cancellation deadline.

The same run refreshed the five Core Text view scenarios. Their medians remain
consistent with the repaired checkpoint: 3.600/9.416 ms small load/traversal,
36.755/3.742 ms for 10 MB short lines, 24.929/123.463 ms for the million-unit
wrapped line, 35.442/15.261 ms pre-highlighted, and 36.855/16.753 ms folded.

## Evidence limits and next work

This lane now covers repeatable small, large, wrapped, attributed, syntax-parse,
bounded-highlight, incremental-edit, cancellation, fold-query and folded-engine
scenarios. It does not measure app decoding/file I/O, editable attachment
reconstruction, window-server frame delivery, interactive typing/selection,
preview, printing, restoration, IME, VoiceOver, energy or true peak memory. It
also does not exercise Intel/Rosetta performance or the app's 50-language catalog
as a whole; JavaScript is the representative real grammar used by this harness.

Next performance work should capture product-level interactive traces in the
RunestoneEditor app and agree latency/memory tolerances across representative
hardware before adding gates. The 10 MB whole-document fold query, long-line
capture query and cancellation tail are explicit candidates for that product-level
budget discussion; the current observations are evidence, not thresholds.
