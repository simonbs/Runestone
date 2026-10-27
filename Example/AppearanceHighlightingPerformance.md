# Appearance-only highlighting refresh

Asynchronous highlighting now reports whether its final effective font runs changed.
Font is the only geometry attribute written by the syntax highlighter; default font,
kern, tab/paragraph settings, text edits, and other existing invalidations still
follow the full layout path. Comparing final runs also handles overlapping captures
that temporarily change a font and then restore it.

When fonts remain equal, the line typesetter keeps measured wrap ranges, hidden
whitespace, fragment IDs, geometry, and continuation state. It recreates CoreText
lines from the newly styled full string at those exact UTF-16 ranges, updates the
fragment tree and cached renderers, and redraws. Token background conversion still
runs before CoreText construction. Color, background, and shadow changes therefore
reach drawing objects without repeating line-break searches. Font changes retain
full reflow. This does not add range chunking or cache eviction.

## Local Release comparison, 2026-10-27

Predecessor: `23cd5eb4e24d68098f046cdf4a13f0e19b863aed` (PR #462), stacked on
`df9b56fd94131c0f60477613dda8f29e7f0aabe7` (PR #461).
Both revisions used Release with testability enabled on the same dedicated iPhone
17 Pro / iOS 27.2 simulator. Baseline measurements were made before production
changes. The local JSON fixture contains 26,141,343 UTF-8 bytes and 11,352 lines;
its longest line contains 58,901 bytes. Fixture data, instrumentation, logs, and
recordings remain local.

### Isolated completion cost

A controlled color-only highlighter measures the production LineController async
completion path after attributes are applied. It retains visible fragment
controllers, checks unchanged geometry, and checks updated CoreText renderer colors.
Initial typesetting and attribute application are recorded separately, outside the
completion interval. Each scenario has one excluded warmup and eight measured
trials. This isolates redundant wrapping; it excludes query/token processing and
new font-classification overhead, which the scrolling measurements below include.

| Longest fixture line | Measured fragments | Predecessor median | Changed median |
| --- | ---: | ---: | ---: |
| Wrapped, viewport prefix | 42 | 1.248 ms | 0.575 ms |
| Wrapped, fully measured | 2,027 | 40.135 ms | 3.996 ms |
| Unwrapped, fully measured | 52 | 1.855 ms | 0.672 ms |

Full wrapped samples ranged from 38.987–42.896 ms before and 3.951–4.079 ms after.
Process CPU medians closely tracked wall time. The unwrapped mode retains the
editor's existing 10,000-point width limit.

A separate 58,901-character synthetic ASCII line measured 1.300→0.577 ms for the
wrapped prefix, 435.719→3.490 ms for the fully measured wrapped line, and
14.642→0.860 ms unwrapped. That synthetic case particularly stresses repeated word
break searches; its ratio must not be generalized to ordinary scrolling.

### Ordinary scrolling

One equivalent pair used the same temporary display-link harness described in
[HighlightingPerformance.md](HighlightingPerformance.md): 120 movement callbacks
plus 30 settling callbacks per phase, requested 60 Hz, identical small JSON query,
slow/fast first traversal, reversal, cached revisit, and horizontal out/back.
Load is separate. This is programmatic scrolling with instrumentation overhead.

| Measurement | Predecessor | Changed |
| --- | ---: | ---: |
| Unwrapped load wall | 1.936 s | 2.353 s |
| Wrapped load wall | 1.811 s | 2.317 s |
| Unwrapped scroll process CPU | 10.676 s | 11.630 s |
| Wrapped scroll process CPU | 3.965 s | 3.227 s |
| Unwrapped callback intervals >25 / >50 ms | 115 / 19 | 134 / 21 |
| Wrapped callback intervals >25 / >50 ms | 1 / 0 | 11 / 1 |
| Unwrapped peak sampled RSS | 2,149.6 MiB | 2,097.2 MiB |
| Wrapped peak sampled RSS | 962.5 MiB | 964.2 MiB |

There is **no demonstrated ordinary-scroll smoothness or memory improvement** in
this pair. CPU results are mixed and callback-stall counts are worse. Unchanged
initial typesetting also slowed in changed-run samples, indicating substantial
runtime/host variance; these results do not isolate a general regression either.
Callback intervals are main-run-loop delivery proxies, not compositor hitch traces.
RSS includes allocator/process history and does not establish retained-cache cost.

Requests matched exactly: 508 started/completed unwrapped, 14 wrapped, no scroll
cancellations. Load starts/cancellations remained 17/1 and 3/1. Reversals, cached
revisits, and horizontal phases started no requests. All paired phase endpoints
had identical offsets and content dimensions.

Main-thread token construction totals were 415.174→501.775 ms unwrapped and
30.799→26.496 ms wrapped. Attribute application, including new font classification,
was 192.370→225.250 ms and 12.967→11.504 ms. Changed appearance refresh totaled
174.048 ms and 8.316 ms, including its nested typesetter preparation. Typesetter
preparation totals were 177.470→194.886 ms and 11.025→9.661 ms; these overlap with
refresh and must not be summed as independent costs. The useful demonstrated
benefit is the isolated long-line completion reduction above.

## Correctness and limits

Regressions distinguish appearance changes from final font changes, including
complete styles and overlapping captures restoring the original font. Partial and
finished refreshes compare wrap ranges, hidden whitespace, dimensions, every caret
offset, and actual renderer pixels with fresh styled typesetting. They exercise
segmented colors inside ligature/Arabic text, composed Unicode, bidi, tabs,
backgrounds, shadows, and later continuation. Controller tests check both fragment
tree and existing renderer updates, plus font reflow against a fresh typesetter.

Editing coverage includes split/join, multiline replacement, undo/redo, syntax
changes, EOF deletion, theme/document replacement, and fresh-editor geometry and
rendering comparisons. The added long-line marked-text case checks immediate text,
UTF-16 selection, marked ranges, and settled rendering before/after commit with
wrapping on/off. Its main-queue barrier does not guarantee a background query has
finished; the fresh-editor oracle synchronously settles both editors.

Physical-device performance and compositor hitch traces remain unverified. No
phone app or primary checkout was modified. Existing fallback Theme property
getters during attribute application are unchanged; reentrant mutation from those
getters is outside this change's verified coverage.

Validation passed 62 focused tests on the final uninstrumented code, including
navigation, composition, editing, range/tokenizer behavior, cut/undo, Writing Tools
rendering/replacement, and the new appearance regressions. Earlier passing
complete-style, embedded-language/stale-request, background-overlay, and existing
composition results were reused. The Release Example build and changed production
SwiftLint checks passed; the build retains pre-existing dependency/example warnings.

Local 30-fps recordings cover wrapped/unwrapped slow drags, fast flings, reversals,
and unwrapped horizontal scrolling. Spread-frame review plus 6-fps motion windows
found no blank viewports, missing bands, or obvious unintended jumps. Newly exposed
lines can briefly await asynchronous coloring; this is not evidence that every
frame is fully highlighted. Settled refreshed pixels are covered by the automated
fresh-renderer oracle. Sampling does not prove absence of every visual defect.
