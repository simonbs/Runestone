# Bounded Tree-sitter comparison experiment

This is a rejected working-tree experiment against Tree-sitter commit
`10eb5ac119eec9cb4267a8e035066473983f5f3a` (v0.27.1). The patch was tested and then
reversed. The submodule is clean. It remains here as reviewable research evidence.

From an otherwise clean submodule at that revision:

```sh
git -C tree-sitter apply --check ../Experiments/TreeSitterComparison/comparison-bounded.patch
git -C tree-sitter apply ../Experiments/TreeSitterComparison/comparison-bounded.patch
```

Alternatively, pass the patch's absolute path. Do not reapply it to an already
patched checkout. Splitting this into an upstream dependency change is deferred.

The shortcut skips a shared immediate hidden parent only when child-slot identity,
positions, visible context/depth, aliases, included ranges, error state, and
external-token guards agree. Every other case retains the existing traversal.
It does not narrow the requested range to the edited line or change parsing.

`native-results.json` is the original native-thread handoff, before coordinator
integration. Its relative artifact paths refer to
`/tmp/runestone-tree-comparison-experiment/`, and its patch filename corresponds
to `comparison-bounded.patch` here. The SHA-256 is
`6e1ae705f4b4814a12cf9b0989219cf6b7af44274cacbd2e68a94eeb49bbeaa8`.

Native comparison medians were 69.0 → 49.7 ms for incremental insertion and
68.3 → 49.5 ms for undo. Independently parsed trees after a middle edit measured
70.5 → 72.2 ms; whole replacement measured 39.5 → 39.1 ms. These are native-host
measurements, not end-to-end editor or physical-device results.

The exact patch passed 69 selected upstream tests and differential checks for
random edits, included ranges, padding/aliases, recursion, malformed trees,
retained snapshots, UTF-16 callbacks, large documents, and sanitizers. Exact
counts and limitations are retained in the JSON. Earlier nested-ancestor and
parser-fragility patches were rejected; their measurements are not claims for
this version.

Coordinator iOS verification passed ordinary and large-file rendering/editing
checks on iOS 18.6 and 26.5. All 24 measured editor operations improved in the
targeted pair, but the no-sharing slowdown remained unresolved. Adaptive and
preflight variants did not establish removal of that regression. The change is
rejected for production under the requested regression bar. See
`Example/LargeFilePerformance.md` for the full audit and retained changes.
