# Large-file performance

Measured 2026-10-27–28 with Xcode 27.2. Paired comparisons use the same iPhone 17
Pro simulator running iOS 26.5. The baseline contains the initial allocation,
line-index, fragment-height, and changed-range buffer fixes on top of `978b808`;
the final column includes prefix reuse and the restricted alphanumeric wrapping
path. These paired measurements predate code folding (`00426ba`).

## Results

Median synchronous milliseconds, baseline → final. Each edit uses five samples
near the end of a middle logical line in a generated 25 MiB document.

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
samples are slower (pure words: 11.99 → 13.94 ms). All 70 paired scrolling endpoints
match across the fourteen editor scenarios.

For supported alphanumeric input at 320 points, first-viewport preparation improves
from 19.01 → 0.625 ms for 60k characters and 578.53 → 10.24 ms for 1 MiB. The latter
includes 8.94 ms of calling-thread CPU time; quoted 1 MiB input takes 19.64 ms
(19.47 ms thread CPU). Short-line JSON editing remains a bottleneck at roughly
160 ms because of incremental parsing and changed-range comparison.

After including code folding, separate iOS 18.6 reruns measured near-end character
insertion at 9.90 ms for wrapped words, 11.87 ms for wrapped JSON, 9.76 ms for
wrapped unbroken ASCII, and 6.07 ms for unwrapped JSON. Folding was disabled during
all timed runs. Baseline and final builds use identical fixture and build settings.

## Rendering and correctness

Synchronous edits can reuse validated ASCII prefix geometry. Every retained
fragment receives a fresh `CTLine` shaped from the updated full paragraph, so
nonlocal syntax recoloring remains correct. The restricted alphanumeric path uses
cluster-break suggestions inside validated runs and native word breaking at
wrappers and boundaries. Unsupported fonts, attributes, and content use the
native path. Separate progress tests protect combining characters, emoji, and CRLF
when a complete character cannot fit the available width.

The ordinary checks cover line-index edits, invalidation, stale highlighting,
snapshot lifetime, appearance changes, shaping fallback, and wrapped edits before
a collapsed section. Independent native-layout comparisons check glyphs, carets,
geometry, and exact renderer pixels. Eight opt-in large-file checks cover editing,
split/join/deletion, undo/redo, fresh parsing, nonlocal recoloring, and viewport
coverage with wrapping on/off. All eight passed on iOS 18.6 and 26.5; the extracted
PR versions were also checked with code folding included. Distributed traversal
visits twelve regions, then EOF and the top, to detect gaps and overlaps away from
the initial viewport.

## Reproduce

With Xcode, `xcsift`, and an installed iOS simulator, run from the repository root:

```sh
git submodule update --init --recursive
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-performance
```

Use a new result directory each time. The script builds Release with testability
and coverage disabled, sets `RUNESTONE_PERFORMANCE=1` in the test runner, and runs
serially. Ordinary test runs skip these expensive cases. Fixtures are generated in
memory; no large documents are committed. To select a smaller set, append test
identifiers:

```sh
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-correctness \
  RunestoneTests/LargeFileCorrectnessTests
```

The default run includes the fourteen editor scenarios, eight correctness checks,
distributed traversal, first-viewport preparation, full-paragraph typesetting, and
isolated line-index measurements. Raw samples and result bundles are saved in the
supplied directory.

## Measurement limits

Fixtures use short 128-byte records and long 60,000-byte records, with syntax
highlighting and wrapping on/off, plus plain ASCII inputs. Highlighted benchmarks
use the test JSON grammar and `(string) @string`. The unwrapped mode retains the
editor's existing 10,000-point width limit, so extreme lines still span fragments.

Editing timings exclude selection preparation, restoration, equality checks,
keyboard, persistence, and application callbacks. The harness disables automatic
scrolling, autocorrection, and spell checking. With five edit samples, p95 equals
the maximum and is not a stable tail-latency estimate. Display-link intervals
measure run-loop delivery rather than compositor hitches. Memory samples include
whole-process allocator history and do not establish cache retention or leaks.
Host activity caused timing variation; simulator results do not establish
physical-device frame rates.
