# Large-file scrolling and editing audit

Measured 2026-10-27–28.

The retained changes reduce near-end character insertion in wrapped, word-filled
25 MiB files from **507 → 11.5 ms** plain and **519 → 12.9 ms** with JSON
highlighting. Wrapper-free alphanumeric lines improve from **783 → 11.8 ms**.
These comparisons use the first round's five fixes as their baseline. All 70
compared scrolling endpoints match exactly across the final 14-scenario matrix.
Short-line JSON editing still takes roughly 160 ms; incremental parsing and
changed-range comparison remain the next substantial bottleneck.

The final production revision passed all eight 25 MiB fresh-editor correctness and
rendering scenarios on iOS 26.5 and 18.6, plus four distributed traversal scenarios
on iOS 26.5. After pruning prototype tests, the ordinary iOS 26.5 suite passed
333 tests, with 29 opt-in cases skipped and zero failures (12.54 seconds).
The retained iOS 18.6 suite also passed 333 tests, with 29 opt-in cases skipped
and zero failures (22.63 seconds), on an available iPhone 16 simulator.

Rendering retains full-paragraph CoreText shaping. Synchronous edits can reuse
validated ASCII prefix geometry, but every retained fragment receives a fresh
`CTLine` shaped from the updated full paragraph so recoloring remains correct.
A restricted alphanumeric path uses cluster-break suggestions only inside a
validated run; paragraph wrappers, boundaries, and unsupported attributes use
native word breaking. Grapheme-progress handling preserves combining characters,
emoji, and CRLF when a native suggestion cannot fit a complete character.
Independent native-layout checks compare ranges, glyphs, caret positions, geometry,
and exact renderer pixels. No regression was found in these checks or inspected
simulator captures; this does not establish physical-device frame-rate guarantees.

### Final performance comparison

Median synchronous milliseconds, first-round baseline → final production. Long-line
edits occur near the end of a middle logical line; each cell uses five samples.

| Scenario | Character | Newline | Join lines | Delete line |
| --- | ---: | ---: | ---: | ---: |
| Word-filled plain, wrapped | 507.19 → 11.50 | 500.18 → 11.81 | 502.60 → 10.44 | 506.53 → 11.87 |
| Word-filled JSON, wrapped | 519.42 → 12.91 | 513.02 → 15.24 | 507.74 → 11.40 | 523.29 → 14.38 |
| Quoted unbroken payload, wrapped | 564.50 → 12.26 | 556.02 → 12.30 | 557.95 → 11.10 | 563.52 → 11.40 |
| Pure alphanumeric, wrapped | 783.45 → 11.75 | 766.17 → 11.97 | 800.51 → 10.56 | 874.37 → 11.57 |
| Pure alphanumeric, unwrapped | 29.18 → 4.59 | 27.84 → 6.50 | 27.59 → 4.78 | 27.85 → 9.04 |

Cold fast scrolling's median synchronous work falls from 8.94 → 4.58 ms for
quoted unbroken wrapped lines and 9.74 → 5.32 ms for pure alphanumeric wrapped
lines. Word-filled wrapped scrolling stays around 8 ms. Some small unwrapped
samples are slower (pure words: 11.99 → 13.94 ms); nearby repeats did not reproduce
the earlier short-plain slowdown. All raw samples remain available rather than
selecting only favorable runs. Callback intervals measure run-loop delivery,
not compositor hitches.

At 320 points, a supported 60k paragraph's first viewport improves from 19.01 →
0.625 ms and a 1 MiB paragraph from 578.53 → 10.24 ms. The final 1 MiB measurement
includes 8.94 ms of calling-thread CPU time. Quoted 1 MiB input takes 19.64 ms
(19.47 ms thread CPU); these larger preparation costs remain visible. Host load
caused variation in earlier runs, so these are simulator measurements rather than
latency guarantees.

The historical first-round tables below compare `978b808` with five initial fixes:
removing temporary attributed substrings during wrapping classification, deriving
UTF-16 byte counts directly, using accumulated fragment height, and freeing the
caller-owned `ts_tree_get_changed_ranges` buffer. Later retained layout changes
are included in the final results above, not those historical tables.

## Reproduce

From the repository root, with Xcode, `xcsift`, and an installed iOS simulator:

```sh
git submodule update --init --recursive
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-perf-new
```

Use a new result directory for each run. The script builds Release with testability
and **code coverage disabled**, sets `RUNESTONE_PERFORMANCE=1` in the test runner,
and runs the benchmarks serially. Fixtures are generated in memory; no large files
are committed. The default run includes the original ten-scenario scrolling/editing matrix,
four wrapper-free ASCII scenarios, distributed traversal, eight fresh-editor rendering comparisons, first-viewport preparation, full-line
typesetting, and line-index measurements. Optional
test identifiers after the result directory select a smaller set. For example:

```sh
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-perf-correctness \
  RunestoneTests/LargeFileCorrectnessTests
```

`RUNESTONE_PERFORMANCE_RESULT` and `RUNESTONE_TRAVERSAL_RESULT` log records contain
raw samples, scenario names, and viewport endpoints. Historical parser diagnostics
are archived under `Experiments/TreeSitterProfiling`; they are outside the compiled
test target. The ordinary test suite skips expensive benchmarks unless the runner
variable is enabled.

## Workloads and measurement limits

The local comparison uses an arm64 Mac, Xcode 27.2, and a dedicated iPhone 17 Pro
simulator running iOS 26.5. Baseline and changed builds use the same benchmark code,
optimization settings, fixture generation, and simulator. Simulator results are
not physical-device frame-rate guarantees.

The matrix contains short 128-byte records and long 60,000-byte records, with
syntax highlighting on/off and wrapping on/off. Two additional plain-text cases
use unbroken letter payloads inside the same JSON-shaped records. Documents are
at least 25 MiB (26,214,403 or 26,220,003 bytes). Highlighted cases use the test JSON
grammar and `(string) @string`, rather than a full application-specific query.

Each scrolling phase requests 60 Hz and runs 90 display-link callbacks: cold slow
movement, cold fast movement, reversal, and revisit; unwrapped cases also move
horizontally out and back. Synchronous movement/layout time and callback intervals
are reported separately. Intervals are main-run-loop delivery proxies, **not
compositor hitch measurements**. The initial continuous traversal covers 30,600
points; a separate test visits twelve regions throughout each highlighted document,
then EOF and the top, checking contiguous viewport coverage.

Editing measures five samples per operation at the start, middle, and end of the
document, plus near the end of a middle long line. It exercises character insertion,
`insertText` with a newline, joining lines, and deleting a line. Selection preparation,
restoration, and full document equality checks are outside timing. With five samples,
reported p95 equals the maximum and is not a stable tail-latency estimate. The harness
disables autocorrection, spell checking, and automatic scrolling and does not make
the editor first responder. App callbacks, persistence, and keyboard costs are excluded.

The existing unwrapped mode has a 10,000-point width limit, so extreme lines still
produce multiple fragments. Traversal memory samples describe the whole test process,
including allocator history; they do not isolate cache retention or establish leaks.

## Historical first-round Release results

The strongest gains are in the repeated character-classification path for long,
unbroken payloads. Typical word-filled lines are mostly unchanged because native
CoreText search remains dominant. All paired scroll-phase endpoints (offsets,
content dimensions, and viewport dimensions) matched exactly.

### Scrolling

Median synchronous work for the cold fast phase, in milliseconds. The last columns
sum display-link intervals over all phases of each scenario; unwrapped cases have
two additional horizontal phases. Counts therefore compare revisions within a row,
not workloads between rows.

| Scenario | Work before → after | Intervals >25 ms before → after | Intervals >50 ms before → after |
| --- | ---: | ---: | ---: |
| long-json-unwrapped | 11.29 → 10.97 | 30 → 30 | 0 → 0 |
| long-json-wrapped | 8.37 → 8.09 | 0 → 0 | 0 → 0 |
| long-plain-unwrapped | 11.20 → 10.87 | 2 → 0 | 0 → 0 |
| long-plain-wrapped | 8.10 → 8.10 | 0 → 0 | 0 → 0 |
| long-unbroken-plain-unwrapped | 29.32 → 16.17 | 89 → 36 | 3 → 0 |
| long-unbroken-plain-wrapped | 13.68 → 9.04 | 1 → 0 | 0 → 0 |
| short-json-unwrapped | 6.49 → 6.43 | 0 → 0 | 0 → 0 |
| short-json-wrapped | 3.55 → 3.51 | 0 → 0 | 0 → 0 |
| short-plain-unwrapped | 5.89 → 5.75 | 0 → 0 | 0 → 0 |
| short-plain-wrapped | 4.24 → 3.79 | 0 → 0 | 0 → 0 |

No changed-run scrolling interval exceeded 50 ms in this pair. Highlighted long
unwrapped lines still produced 30 intervals over 25 ms. This is useful evidence,
not a guarantee of hitch-free physical-device scrolling.

### Editing

Median synchronous milliseconds, before → after. Short-line rows use the middle
of the document; long-line rows use the near-end position of a middle long line.
Each cell represents five measured edits with restoration between samples.

| Scenario | Character | Newline | Join lines | Delete line |
| --- | ---: | ---: | ---: | ---: |
| long-json-unwrapped | 9.56 → 10.15 | 13.26 → 12.84 | 9.72 → 9.44 | 13.77 → 13.36 |
| long-json-wrapped | 513.97 → 504.99 | 513.36 → 506.66 | 507.93 → 497.91 | 512.26 → 505.01 |
| long-plain-unwrapped | 9.08 → 9.27 | 9.86 → 9.70 | 8.86 → 8.65 | 11.13 → 11.09 |
| long-plain-wrapped | 511.62 → 502.30 | 509.60 → 503.28 | 509.68 → 497.54 | 509.64 → 502.94 |
| long-unbroken-plain-unwrapped | 61.63 → 26.44 | 61.73 → 26.17 | 59.81 → 24.26 | 62.94 → 27.56 |
| long-unbroken-plain-wrapped | 1000.34 → 551.05 | 985.84 → 549.77 | 982.89 → 548.28 | 989.61 → 552.84 |
| short-json-unwrapped | 171.19 → 155.73 | 169.80 → 156.62 | 179.00 → 161.79 | 171.39 → 157.58 |
| short-json-wrapped | 160.13 → 155.24 | 161.62 → 156.18 | 164.63 → 160.85 | 158.16 → 153.80 |
| short-plain-unwrapped | 5.18 → 5.56 | 5.69 → 6.02 | 4.82 → 5.02 | 4.82 → 5.12 |
| short-plain-wrapped | 4.38 → 5.28 | 5.44 → 6.04 | 4.61 → 4.76 | 4.56 → 5.14 |

A focused paired repeat investigated the small increases in the short plain-text
rows. Middle-of-document character insertion measured 4.98 → 4.97 ms unwrapped
and 5.22 → 5.09 ms wrapped; newline/join/deletion medians also did not increase.
The original sub-millisecond differences did not reproduce. Both original and
repeat results are retained rather than selecting only favorable samples.

Character insertion near the start of the long unbroken payload improved from
32.87 → 18.74 ms wrapped and 69.96 → 39.51 ms unwrapped. The remaining roughly
500–550 ms near-end wrapped edits and roughly 150 ms short-line JSON edits remain
user-visible stalls. The changes do not meet a universal low-latency editing target.

### Isolated full-line typesetting

Eight samples after one warmup; same fragment counts in both revisions. These
measure the full paragraph rather than just the visible prefix.

| Fixture / width | Before median | After median |
| --- | ---: | ---: |
| 60,000 ASCII letters / 320 pt | 1,212.02 ms | 773.07 ms |
| 60,000 ASCII letters / 10,000 pt | 68.80 ms | 25.46 ms |
| Mixed Unicode / 320 pt | 21.16 ms | 14.58 ms |
| Mixed Unicode / 10,000 pt | 13.09 ms | 13.36 ms |

The last pair differs by about 0.27 ms; it does not demonstrate a useful speedup.
Line-index-only edits remain sub-millisecond and are not the source of the large
end-to-end stalls. The leak fix is justified by Tree-sitter's allocation contract,
not by attributing whole-process RSS changes to that allocation.

## Historical first-round hotspots and rejected experiments

A symbolicated CPU sample of editing the short-line JSON array attributes most
main-thread work to Tree-sitter changed-range comparison and incremental parsing.
The diagnostic reads only one 4 KiB input chunk for a character edit, so repeated
whole-document input copying is not the cause. Resetting the parser or retaining
an old-tree snapshot does not materially change this cost. The measured upstream
`parser.c` and `get_changed_ranges.c` implementations also match
[nightly dfe7708](https://github.com/tree-sitter/tree-sitter/tree/dfe770858e3cfd8e8b29a79ea17da390a6f60319/lib/src);
I found no ready upstream fix to adopt. Restricting invalidation to edited lines
would be incorrect when an edit changes syntax farther away.

Long wrapped-line samples instead concentrate in CoreText's native line-break
search and ICU traversal. Direct UTF-16 backing did not improve this. A cached
break-opportunity prototype was much faster but failed differential tests for
punctuation, whitespace, fonts, widths, and offsets. It was rejected and removed.
The production path retains native CoreText behavior. The subsequent retained layout changes address these measured long-line stalls;
short-line JSON remains slow. The audit does **not** establish universally smooth
editing of arbitrary 25 MiB files.


## Historical first-round regression and visual verification

The ordinary Release suite ran 311 tests successfully on both iOS 26.5 and iOS 18.6.
Opt-in stress cases were skipped in these ordinary runs. Coverage includes editing,
undo/redo, marked composition, asynchronous highlighting/cancellation, appearance
refresh, font-driven reflow, Unicode caret geometry, navigation, and renderer pixels.
New default-on checks compare character classification and wrapping to the legacy
behavior and independently reconstruct line-index expectations after Unicode and
CRLF edits. Strict SwiftLint passed for every changed Swift file.

The four 25 MiB fresh-editor oracle scenarios passed on both iOS 26.5 and iOS 18.6,
covering short and long Unicode JSON records with wrapping on/off. Each scenario checks six
checkpoints: character insertion, a split that creates invalid syntax, joining,
line deletion near EOF, undo, and redo. Long-line character/split/join edits occur
near the logical line end. Full document contents and selection contracts are
checked against independent expectations. Visible logical fragments are compared
with a fresh parse for ranges, hidden whitespace, geometry, glyphs, positions,
colors/fonts/backgrounds, and exact renderer PNGs. Both viewports must have
continuous coverage. The oracle accounts for subpixel scroll-offset rounding and
uses the existing cached renderer when an edge fragment's view was recycled;
it does not recreate or restyle the edited renderer to make the comparison pass.

All ten performance scenarios and four distributed traversal cases passed, along
with the full-line typesetting and line-index checks. Distributed traversal checked
selection preservation, nonempty glyph rendering, finite dimensions, full viewport
coverage, and adjoining fragment edges without gaps or overlaps. Maximum measured
scroll-layout time across its regions was 13.72 ms. Cold navigation into a long
wrapped paragraph still reached 531.07 ms; this agrees with the remaining full-line
CoreText bottleneck and is not hidden by the continuous-scroll results.

The Release Example app also opened the generated 26,220,003-byte file using its
existing JavaScript highlighter. Real simulator gestures exercised slow drags,
fast flings, reversals, EOF navigation, switching wrapping off, and horizontal
out/back scrolling. Software-keyboard insertion near a long line's end, a newline
with automatic indentation, and backspace joining were captured separately.
Inspected captures showed continuous highlighted text and no blank viewport or
visible corruption. The first plugin recording did not save; replacement captures
used the native simulator recorder. Captures were inspected as sampled frames,
not treated as an automated appearance oracle or compositor timing trace.

Physical-device performance, every possible asynchronous frame, other font/language
combinations, interactive rotation, and application-specific persistence callbacks
are not established by this audit. Passing regression checks are evidence for these
changes, not a proof of zero possible regressions.

Local raw artifacts for this run are under `/tmp/runestone-large-file-perf/`:
`baseline-release.log/.json`, `final-release.log/.json`, `.xcresult` bundles,
`large-correctness-cached-renderer.log`, `large-correctness-ios18.log`,
`short-json.sample.txt`, `long-wrapped.sample.txt`, and `final-*.mp4` captures.
They are intentionally outside version control; the tests and script regenerate
fixtures and measurements.

## Subsequent experiments — completed integration and rejected trials

These experiments share this worktree, with independent threads owning separate
prototypes and the coordinator controlling builds, comparisons, and retention.
Raw evidence and the coordination record are in
`/tmp/runestone-performance-round2/`. Prefix reuse, guarded whole-body and quoted
alphanumeric layout, and grapheme-progress fixes are retained and verified. The
final editor-wide results appear above; isolated prototype results below describe
the investigation history.

### Native changed-range comparison

An isolated trial applied a bounded shared-parent shortcut to the Tree-sitter
submodule, then reversed it after the remaining regression could not be resolved.
The submodule is clean. The portable patch, exact
native validation matrix, and reproduction notes are in
[`Experiments/TreeSitterComparison`](../Experiments/TreeSitterComparison/README.md).
It preserves the complete changed-range result and does not change parsing.

This version passed 335 executed ordinary tests on each of iOS 26.5 and 18.6
(26 optional skips per run), all four 25 MiB editing/rendering oracles on each,
and four distributed traversal cases on iOS 26.5. The two short-JSON editor
scenarios and parser diagnostics also passed. All ten paired scroll endpoints
matched exactly. Compared with the baseline repeat, middle character insertion
measured 158.96 → 143.06 ms unwrapped and 162.55 → 148.65 ms wrapped. All 24
measured editing medians improved by 4.5–14.4% in that pair. These are still
user-visible stalls, not a completed low-latency editing target.

Native-host comparison tests show roughly 28% faster incremental comparison, but
also a 1.6 ms / 2.3% overhead when comparing independently parsed 25 MiB trees.
Adaptive and preflight variants did not establish removal of that overhead, so
the comparison changes are rejected for production. An earlier
ancestor-search version was rejected for a severe no-sharing slowdown; a separate
parser-fragility change was rejected for an incorrect JSON tree and changed range.
None of these comparison/parser changes is applied.

Concurrent unrelated simulator/build activity caused substantial noise in the
first baseline's scrolling intervals. Both baseline runs and the candidate run
remain available; the editor comparison above uses the baseline repeat. No
compositor or physical-device smoothness claim is made from those intervals.

### Restricted layout prototypes

Both prototypes preserve full-paragraph CoreText shaping and compare ranges,
glyphs, positions, caret/hit testing, geometry, and production-renderer pixels
against fresh native layout. The measured revisions' ordinary cases passed on both
tested OS versions. Subsequent extensions completed verification in the final
production revision described above.

- A prefix cache for ASCII word/space lines with validated default shaping
  attributes reduced a near-end edit in a roughly 60k-character line from a
  786.88 ms fresh-layout median to 2.23 ms including the replacement cache.
  Unbroken lines and JSON punctuation still fell back or received no useful gain.
- A whole-line ASCII alphanumeric cluster-break prototype reduced full 60k-line
  layout from 975.33 → 3.16 ms at 320 points and 26.54 → 1.56 ms at 10,000 points.
  JSON wrappers still fell back. These measurements include admission and snapshot
  costs, use few samples, and were taken with recorded background host activity.

Integration subsequently verified real theme colors, generated tab settings,
appearance transitions, partial continuation, and prefix-run reconstruction. The
numbers immediately above remain isolated prototype results; the final table
reports editor-wide measurements.

The first unbroken-line production trial subsequently passed 354 executed ordinary
tests on each tested OS version (33 optional skips), five focused grapheme/progress
cases, and independent native-layout checks. In new wrapper-free 25 MiB editor
scenarios, wrapped near-end character insertion measured 783.45 → 10.32 ms,
newline insertion 766.17 → 11.74 ms, joining 800.51 → 10.51 ms, and line deletion
874.37 → 13.29 ms. All twenty paired scroll endpoints matched. These results do
not apply to JSON wrappers, which remain outside this fast path.

First-viewport probes also measured 19.01 → 0.90 ms for a supported 60k paragraph
and 578.53 → 37.33 ms for a supported 1 MiB paragraph at 320 points. Cross-process
fallback measurements varied substantially. A balanced same-process comparison
completed 48 measured pairs with identical consumed text and fragment checks.
Paired total medians were close for JSON wrappers and words; a late-Unicode
paragraph consistently paid about 0.85 ms extra preparation for the admission
scan. Narrow unsupported-font samples had severe variation in both directions.
The larger cross-process fallback slowdowns were not consistently reproduced;
these results do not establish a universal absence of overhead.

The expanded recoloring-aware prefix prototype passed 27 executed cases and a
256-case seeded search (1,024 exact comparisons). Its production integration passed 363 executed ordinary tests on each OS
(36 optional skips), all six 25 MiB editing/rendering oracles on each OS, and
four distributed traversal cases on iOS 26.5. It performs no cold snapshot work,
uses explicit edit-only permission, bounds reconstruction to the request, and
creates fresh drawing runs. New ASCII fresh-editor
oracles deliberately recolor unchanged text after an edit to expose stale runs.
The integrated path passed both new ASCII cases, including nonlocal syntax
recoloring. The ordinary suites completed in 16.31 s (iOS 26.5) and 9.81 s
(iOS 18.6); the six large-file oracles took 42.11 s and 58.70 s respectively.

The iOS 26.5 ordinary run spent 149 seconds in its first existing asynchronous
highlighting test, which does not call the changed typesetter; iOS 18.6 completed
the suite in eight seconds. This concentrated startup delay is retained in raw
results and is not attributed to editor-layout work without a trace.

Two initial snapshot tests mutated already-installed paragraph objects in place.
Apple explicitly disallows this because attribute caching/uniquing assumes stable
values. The tests now replace attributes through supported attributed-string APIs
using newly configured immutable values, retaining old-snapshot and exact rendering
checks. Original failing sources and logs are preserved; no custom attributed-string
storage workaround is retained. See [Apple's attribute-mutation contract](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AttributedStrings/Tasks/ChangingAttrStrings.html).

### Completed cancellation investigation

The cancellation thread is archived with its frozen prototype and handoff retained
under `/tmp/runestone-parser-cancellation-experiment/`. Three ordinary cases and
both 25 MiB recovery-oracle cases passed. Median request-through-reset latency was
0.353 ms for short JSON and 5.470 ms for long JSON. Integration is deferred to a
separate load/switch lifecycle change requiring atomic injection publication and
stale-completion protection. It does not improve steady-state typing or scrolling.


## Final verification and retained tests

The final eight large-file oracles cover short and long Unicode JSON, ASCII words,
and quoted unbroken ASCII payloads, each with wrapping on/off. They check expected
text, selections, edit/split/join/deletion, undo/redo, fresh parser results,
nonlocal recoloring, continuous viewport coverage, and exact fragment rendering.
All eight passed on iOS 26.5 and 18.6. The final iOS 18.6 run used an iPhone 16 Pro
Max simulator; timed baseline/final performance comparisons used the same iOS 26.5
iPhone 17 Pro simulator. The final 14-scenario performance matrix and four distributed
traversal cases passed. All 70 paired endpoints matched exactly.

The retained default-on additions focus on observable production contracts:
seven prefix-reuse tests, ten native-layout compatibility tests sharing one
independent native oracle, five grapheme-progress tests, two legacy line-break
compatibility tests, and Unicode/CRLF line-index editing coverage. They exercise
supported edits, snapshot lifetime, asynchronous highlighting, appearance changes,
unsupported shaping fallbacks, fragment-tree continuation, glyphs, carets, and
pixels. Copied prototype implementations, policy/model checks, storage-class
observations, seeded research searches, and deferred cancellation experiments were
moved outside the test target under `Experiments/`. Actual production benchmarks
and the distinct opt-in large-file integration checks remain available.

Final raw results are under `/tmp/runestone-performance-round2/`, including
`final-editor-matrix`, `final-large-oracles-ios18`,
`final-large-oracles-traversal-ios26`, `final-viewport-cpu-diagnostic`, and
`retained-production-regression-ios26` and
`retained-production-regression-ios18-available` logs and result bundles. The report retains
historical counts above as investigation history; the final ordinary test count
is the smaller retained suite described at the start.
