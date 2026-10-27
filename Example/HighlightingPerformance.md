# Highlight request lifetime

Ordinary layout keeps an equivalent asynchronous request in flight instead of
canceling and restarting it. Text/parse invalidation, theme or language changes,
line removal, leaving the viewport, and synchronous destination preparation cancel
obsolete requests. Both the request input and operation identity are checked before
applying styles, including after client theme callbacks. Canceling a finished
Operation alone is insufficient to reject its queued main-thread callback.

Each asynchronous request owns copied Tree-sitter trees and shares frozen predicate
text with other requests from the same parse/edit generation. Query iteration checks
cancellation between matches and captures. A single Tree-sitter call or regular
expression evaluation cannot be interrupted. Completed/canceled requests release
their snapshots; synchronous destination preparation still applies styles before
measuring geometry. Destination preparation also invalidates layout when the
scroll offset stays unchanged, so existing visible renderers receive those styles.

## Local Release comparison, 2026-10-27

Predecessor: `df9b56fd94131c0f60477613dda8f29e7f0aabe7` (PR #461).
Both versions used the same dedicated iPhone 17 Pro simulator, iOS 27.2, Release
with testability enabled. The local JSON fixture has 26,141,343 UTF-8 bytes,
11,352 lines, and a maximum line length of 58,901 bytes. No fixture, benchmark
instrumentation, logs, or recordings are included in this repository.

A temporary display-link harness requested 60 Hz and drove the same eight phases:
slow/fast first traversal, slow/fast reversal, slow/fast revisit, horizontal out/back.
Each phase had 120 movement callbacks and 30 settling callbacks. It used an identical
small JSON highlighting query in both versions. This is programmatic scrolling,
not touch-input performance or the Example's full language query. Measurements
include local lock/clock instrumentation overhead. Other development processes on
the host and simulator scheduling introduce substantial variance.

There is **no demonstrated steady-scroll speedup** in this sample. Neither version
canceled requests during the sampled ordinary traversal: both started/completed
508 requests unwrapped and 14 wrapped after loading. Initial layout changed from
32 starts/16 cancellations to 17/1 unwrapped, and from 4/2 to 3/1 wrapped.

Two runs per version produced these ranges (load is reported separately):

| Measurement | Predecessor | Changed |
| --- | ---: | ---: |
| Unwrapped load wall time | 1.887–2.103 s | 1.894–2.224 s |
| Wrapped load wall time | 1.823–1.922 s | 1.760–2.105 s |
| Unwrapped scroll process CPU | 10.014–10.850 s | 10.347–11.275 s |
| Wrapped scroll process CPU | 2.060–3.534 s | 3.717–3.962 s |
| Unwrapped callback intervals >25 ms | 118–128 | 108–119 |
| Wrapped callback intervals >25 ms | 2–9 | 2–5 |

Callback intervals measure main-run-loop delivery, not compositor presentation or
official hitch duration. Cached revisits had no highlighting requests in either
version. On the first paired unwrapped traversal, background capture totals were
106/109 ms, main token construction 422/492 ms, main attribute application 203/237 ms,
and typesetter preparation 176/204 ms (predecessor/changed). These do not establish
a general CPU improvement. Peak process RSS across unwrapped runs was roughly
2.0–2.1 GiB in both versions; allocator history makes direct RSS attribution weak.
Frozen predicate text retains an additional document-sized UTF-16 copy (roughly
50 MiB for this fixture), an explicit correctness/memory tradeoff.

The useful measured improvement is stopping abandoned query work. A separate
synthetic single-line JSON benchmark canceled a running query after about 2–3 ms.
All five trials per size were executing at cancellation. Median remaining worker
wall time and whole-process CPU after cancellation were:

| Numeric tokens / ASCII size | Predecessor wall / CPU | Changed wall / CPU |
| --- | ---: | ---: |
| 30,000 / 60,001 characters | 40.326 / 40.370 ms | 0.141 / 0.204 ms |
| 300,000 / 600,001 characters (stress) | 670.783 / 671.109 ms | 0.072 / 0.344 ms |

These deliberately dense synthetic lines demonstrate cooperative cancellation,
not a claim that the supplied JSON fixture or a physical device has those costs.

## Correctness coverage and limits

Focused regressions cover equivalent request reuse; cancellation/revisit; invalid
inputs; cancellation after captures finish; reentrant theme cancellation; copied
tree/predicate lifetime; query cancellation; and synchronous destination geometry.
The editing oracle compares wrapped/unwrapped Unicode, bidi, and tabs with a fresh
editor after split/join, multiline replacement, undo/redo, syntax-changing edits,
EOF deletion, and document/theme replacement. It checks caret/line/content geometry
and actual visible fragment rendering at start/end revisits.

Physical-device performance, compositor hitch traces, and marked-text composition
while long wrapped-line highlighting is pending remain unverified. Existing
composition tests cover commit notifications, selection, and marked character pairs.
EOF navigation/ordinary gesture captures complement automated geometry/rendering
checks, but sampled captures do not prove absence of every possible visual glitch.

Validation executed the 302-test Release unit suite: 301 passed and the new
rendering oracle exposed the existing no-op destination redraw bug. After the
layout invalidation fix, all 22 affected lifecycle/query/highlighting/navigation
tests passed, including the unchanged oracle. The Release Example build, changed
production-file SwiftLint check, and `git diff --check` also passed. Unaffected
passing tests were reused instead of rerunning the entire suite.

Final Release gesture captures exercised slow drags, fast flings, reversals,
unwrapped horizontal scrolling, and wrapped EOF navigation followed by reverse
scrolling. Review of spread frames and denser 6-fps windows found no blank
viewports, missing bands, obvious unintended jumps, or color loss in those samples.
The isolated simulator was used throughout; no physical-device app was replaced.
