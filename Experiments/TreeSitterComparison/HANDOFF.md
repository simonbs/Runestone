# Tree-sitter comparison investigation — final handoff

**Final recommendation: reject this lead for production under the user's strict zero-regression requirement.** The coordinator accepted this recommendation and owns reversing the bounded patch from the actual worktree submodule. All artifacts below are research only. This supersedes earlier retention recommendations in `results.json` and `results-final.json`; those files and their patches remain unchanged.

All native processes have finished. No further experiments, builds, tests, or measurements are scheduled. This investigation did not modify repository files or the actual submodule; the coordinator separately applied the bounded patch for the iOS trial and will reverse it.

Experiment root: `/tmp/runestone-tree-comparison-experiment/`

Source worktree used for read-only repository access: `/Users/simonbs/.codex-workspaces/worktrees/ios-a22708cc-b3f4-4172-b4bc-c639551c82ab/runestone`

Tree-sitter base: `10eb5ac119eec9cb4267a8e035066473983f5f3a` (v0.27.1).

## Variants and disposition

| Variant / artifact | Disposition and evidence |
|---|---|
| `rejected-parser.patch`; `parse-only/`, `parse-only.dylib` | **Rejected for correctness.** Excluding ignored repetition shifts from reduction fragility roughly halved parsing time, but seed 3, edit 20 produced the wrong JSON error tree. Inserting `é` at byte 1924 yielded `[1924,1926)` instead of `[1924,2015)`. Baseline matched fresh parsing; candidate did not. See `reproduce-parser.log` and `counterexample-first/`. |
| `candidate/`, `candidate.dylib` | Combined parser-fragility and initial comparison experiment. **Rejected**, since it contains the incorrect parser change. Its initial speedups must not be presented as retainable. |
| `comparison-only.patch`; `comparison-only/`, `comparison-only.dylib`, `comparison-final.dylib` | Original nested ancestor search. **Rejected for no-sharing performance.** The guarded version retaining this search measured 171.3834 ms versus baseline 0.0790 ms at hidden depth 512. Original recommendation and approximately 27% incremental headline are superseded. Original `results.json` preserved. |
| `comparison-guarded/`, `comparison-guarded.dylib` | Added projected visible-depth parity, but retained nested ancestor search. **Rejected for the same severe depth regression.** |
| `comparison-immediate.patch`; `comparison-immediate/`, `.dylib` | Limited checks to immediate hidden parents. **Superseded.** Removed the quadratic search, but a 25 MiB independently parsed middle-edit workload initially measured 94.609 ms versus 72.679 ms baseline. Later runs varied; do not treat that first ratio as a universal effect. |
| `comparison-reordered/`, `.dylib` | Moved cheap parent rejection before current-node visibility checks. **Not selected.** No convincing benefit; first no-sharing median was worse and subsequent measurements were variable. |
| `comparison-child-slot/`, `.dylib` | Added cheap current-child-slot address equality. **Superseded** by the bounded version with an error-cost guard. |
| `comparison-bounded-final.patch`; `comparison-bounded-final/`, `.dylib` | Most thoroughly validated candidate and the coordinator's iOS trial patch. **Rejected for production retention under the strict regression bar.** Incremental comparison improved about 28%, but a controlled 25 MiB no-sharing middle-edit case retained 1.6255 ms / 2.3% overhead. See detailed results below. |
| `comparison-adaptive-16.patch`; `comparison-adaptive-16/`, `.dylib` | **Rejected as a remedy.** Stopped probing after 16 consecutive misses, resetting after a hit. Cutoff actually occurred by UTF-16 byte 1026, but paired process-CPU overhead remained a median 1.011 ms, slower in 11/12 pairs. |
| `comparison-preflight-prototype/` | **Rejected design goal.** Plain `static inline impl(..., bool)` with constant call arguments still compiled to one implementation with a per-iteration enable load/branch at `-O3`, `-O2`, and `-Os`. Its 16 visible iterator steps were also not a strict work bound through hidden chains. Not benchmarked. |
| `comparison-preflight-specialized.patch`; `comparison-preflight-specialized/`, `.dylib` | **Research only; not recommended for production.** A private include holds one comparator body instantiated twice with preprocessing constants. Generated O3 code has separate original and optimized loops. A fixed-capacity raw-node probe has a total budget of 32 pops/pushes, no allocations, and bypasses unedited roots. It retained incremental gains but did not establish no-sharing non-regression: final measurements were confounded, including materially different identical-baseline controls. No causal new regression is claimed. No broad correctness or iOS validation was run for this prototype. |
| `comparison-adaptive-diagnostics/`, `comparison-adaptive-16-diagnostics/` | Instrumentation only, not integration candidates. Their timing output is explicitly excluded from performance evidence. |

### Frozen patch identities

Bounded patch SHA-256:

```text
6e1ae705f4b4814a12cf9b0989219cf6b7af44274cacbd2e68a94eeb49bbeaa8
```

Bounded `get_changed_ranges.c` SHA-256:

```text
2bf624521b7cd566ed9ba6eec07be52b9a9abf74946c3e4e5142e50223df5a5a
```

Adaptive patch SHA-256:

```text
d62068ca224d3a99a3e573b3cdd006c4e636de19456726bc6e5d9cc6820de7b2
```

Research-only specialized preflight patch SHA-256:

```text
cdde3734ad5345856df28268b5cf1b50dbf2439cd9adf4dc458060664fafde6e
```

## Bounded candidate: measured benefit and remaining tradeoff

Native Apple clang, `-O3 -DNDEBUG`; 25 MiB ASCII-equivalent JSON, approximately 50 MiB UTF-16LE input; 204,800 records of 128 characters; 4 KiB parser callback. Incremental ABBA measurements have 12 post-warmup samples per engine/direction. Final bounded measurements were run without this investigation's builds/tests concurrently active.

| Comparison workload | Baseline median | Bounded median |
|---|---:|---:|
| Character insertion | 69.0035 ms | 49.7180 ms |
| Undo | 68.2665 ms | 49.5430 ms |
| Middle edit, new tree independently parsed | 70.5490 ms | 72.1745 ms |
| Whole-document replacement, independent parses | 39.4680 ms | 39.1030 ms |
| Hidden-depth 512, no sharing (five-sample means) | 0.0744 ms | 0.0760 ms |

The no-sharing middle-edit median overhead is **1.6255 ms / about 2.3%**. A second identical baseline control measured 70.6695 ms. Process-CPU medians were 70.4415 ms and 70.5495 ms for the baseline controls, versus 72.1670 ms for the bounded candidate. The whole-replacement difference is small and should not be promoted as a material speedup.

Primary logs: `benchmark-bounded-final-abba-*.csv`, `benchmark-wholesale-bounded-final.csv`, `benchmark-hidden-bounded-final.log`. `results-final.json` has the exact matrix, hashes, source revision, fixture revisions, and limits.

The final bounded guards are: same current child-slot address; immediate hidden parents only; equal current depths and projected visible contributions; equal parent identity and byte/point position; unchanged subtree; no external tokens; zero error cost; no intersecting included-range change; compatible enclosing symbols/aliases. Every miss uses the existing traversal.

Shared hidden parents containing errors are reachable. Targeted cases counted 93,561 shared, unchanged, nonzero-error-cost/no-external-token occurrences after edits, plus 9,918 identity-case occurrences; these are not unique-node counts. This supports the conservative error guard but does not prove an error-range bug in earlier variants.

## Adaptive result

Diagnostics across all 56 large-fixture comparisons found first reuse after three misses and a maximum run of seven misses between hits. The budget of 16 provided headroom. Some small malformed cases found their first hit only after 1,133 misses, so the adaptive version deliberately forfeits possible later gains in such cases.

In the 25 MiB independently parsed middle-edit case, instrumentation confirmed exactly 16 attempts, zero hits, and cutoff at byte 1026. Whole replacement had only four eligible attempts. Incremental character comparisons had 204,811 attempts and 204,799 hits without disabling.

| Comparison | Baseline median | Adaptive median |
|---|---:|---:|
| Incremental insertion | 67.7960 ms | 50.5390 ms |
| Undo | 67.6165 ms | 50.5205 ms |
| No-sharing middle edit | 69.9670 ms | 71.1570 ms |
| Whole replacement | 37.3670 ms | 37.6165 ms |

No-sharing middle-edit wall ranges: baseline 67.256–70.855 ms; adaptive 68.161–72.194 ms. Paired process-CPU delta: median **+1.011 ms**, positive in **11/12 pairs**, range −0.249 to +1.567 ms. The budget really stopped probing early, but that did not remove the measurable remaining cost. Its specific cause was not isolated; the budget condition/compiled loop remains. Further threshold tuning is unlikely to resolve a roughly 1 ms cost after cutoff at byte 1026.

See `results-adaptive.json`, `benchmark-adaptive-wholesale.csv`, `benchmark-adaptive-paired-*.csv`, `adaptive-cutoff-wholesale.log`, and `adaptive-cutoff-incremental.log`.

## Final preflight assessment and variability

Plain constant-argument C specialization failed the intended code-generation requirement. Evidence:

- `preflight-O3.s:1252–1253`: enable reload and branch inside the comparison loop.
- `preflight-O2.s:1220–1221`: same.
- `preflight-Os.s:823–824`: same.

The portable private-include prototype did produce distinct original and shared loops in `preflight-specialized-O3.s`, at lines 1094 and 2083 respectively. The original loop has no enable check. It keeps one source traversal body in `comparison-preflight-specialized/src/get_changed_ranges_impl.h`, at the cost of an unusual source convention and two compiled loops.

The selector is heuristic: a shared raw hidden node is a potential shortcut opportunity, not proof that the main traversal will use it. False negatives lose optimization. The full bounded comparator checks remain authoritative. The raw-node budget is strict; unlike visible iterator steps, it cannot traverse an unlimited hidden chain within one charged step.

The first measurement was strongly contaminated: no-sharing wall times ranged roughly 70 ms to more than one second. It favored the candidate in median process CPU (74.0525 vs 77.1965 ms), while wall medians were 135.579 vs 134.061 ms. This is not reliable evidence of improvement or regression.

The repeat included two identical baseline controls:

| No-sharing middle-edit CPU | Median | Range |
|---|---:|---:|
| Baseline control 0 | 75.4215 ms | 71.595–87.183 ms |
| Identical baseline control 1 | 77.9215 ms | 71.341–106.510 ms |
| Specialized preflight | 82.5190 ms | 69.827–98.763 ms |

Paired candidate/control-0 CPU delta was +4.5115 ms, positive in 7/12 pairs. Identical-control delta was itself +2.7055 ms, also positive in 7/12 pairs. Whole-replacement CPU medians were 42.1940, 42.0625, and 42.1610 ms respectively. The repeat therefore **does not identify a causal candidate slowdown**, but it also **does not demonstrate non-regression**. Under the strict bar, the added machinery is not justified by these results.

A 50-pair-per-depth CPU repeat showed no consistent hidden-depth penalty; depth-512 CPU medians were 0.082 ms baseline and 0.078 ms candidate. These small-case results do not resolve the large-case uncertainty.

See `archive-handoff.json`, `benchmark-preflight-wholesale.csv`, `benchmark-preflight-wholesale-repeat.csv`, `benchmark-preflight-hidden-cpu.csv`, and `benchmark-preflight-abba-*.csv`. No broad revalidation was performed for either preflight prototype because performance acceptance was not established.

## Validation already completed on the exact bounded patch

| Check | Count / result |
|---|---|
| Upstream tree tests | 12 passed |
| Upstream parser tests | 51 passed |
| Upstream feature-corpus test | 1 passed, local feature grammars |
| Upstream JSON/JavaScript/HTML/Python/Rust corpus tests | 5 passed |
| UTF-8 randomized edit chains, five grammars | 5,000 passed |
| UTF-16LE 4 KiB callback + retained snapshots, five grammars | 5,000 passed |
| Included-range operations, both input setups | 2,400 passed |
| Padding/aliases/recursive syntax, shared and independent trees, both encodings | 54,000 exact-range comparisons passed |
| Malformed/error/snapshot fixtures, both encodings | 12,000 exact-range comparisons passed |
| AddressSanitizer + UndefinedBehaviorSanitizer | 1,000 edits passed, no diagnostics |
| 25 MiB JSON, UTF-16 callback + snapshots | 4 edits passed |

Total native differential operations/comparisons: **79,404**, plus **69 upstream tests**. No candidate-versus-baseline tree or changed-range mismatch. The generic long Python chains had 22 UTF-8 and 21 UTF-16 incremental/fresh discrepancies shared identically by both engines; targeted boundary/error tests did not exhibit those discrepancies. Sanitizer engine and harness were instrumented; grammar objects were not.

Baseline upstream setup initially encountered cache-lock permission failures (18 parser cases plus the feature-corpus test). After directing `XDG_CACHE_HOME` into this experiment directory, only those failed cases were rerun and passed. The exact final bounded candidate passed all 69 selected tests in one run. Rust 1.90.0, Cargo dependencies, cloned grammar fixtures, and scratch files are under this experiment directory. No Wasm/full-workspace suite was run.

Coordinator-reported iOS results (not run by this chat): all 335 ordinary tests on iOS 26.5 and 18.6; all four large editing/rendering cases on both; four traversal cases on 26.5. Targeted editor timing showed benefit. These successful correctness results do not remove the separate no-sharing performance objection.

## Commands already used / reproduction references

These are records, not instructions to restart work. The coordinator controls CPU scheduling. Commands were launched with the exact source worktree as their working directory and use absolute temporary paths.

Set a shell variable for readability:

```sh
experiment=/tmp/runestone-tree-comparison-experiment
```

Native build pattern:

```sh
clang -O3 -DNDEBUG -dynamiclib \
  -I"$experiment/comparison-bounded-final/include" \
  -I"$experiment/comparison-bounded-final/src" \
  "$experiment/comparison-bounded-final/src/lib.c" \
  -o "$experiment/comparison-bounded-final.dylib"
```

Differential edits and UTF-16/callback/snapshot coverage:

```sh
"$experiment/validate" "$experiment/baseline.dylib" \
  "$experiment/comparison-bounded-final.dylib" 1000
EXPERIMENT_UTF16=1 EXPERIMENT_CALLBACK=1 EXPERIMENT_SNAPSHOT=1 \
  "$experiment/validate" "$experiment/baseline.dylib" \
  "$experiment/comparison-bounded-final.dylib" 1000
EXPERIMENT_UTF16=1 EXPERIMENT_CALLBACK=1 EXPERIMENT_SNAPSHOT=1 \
  "$experiment/validate-included" "$experiment/baseline.dylib" \
  "$experiment/comparison-bounded-final.dylib"
EXPERIMENT_REPETITIONS=204800 EXPERIMENT_LARGE_JSON=1 \
EXPERIMENT_UTF16=1 EXPERIMENT_CALLBACK=1 EXPERIMENT_SNAPSHOT=1 \
  "$experiment/validate" "$experiment/baseline.dylib" \
  "$experiment/comparison-bounded-final.dylib" 4 42 json
```

Boundary/error harness commands and seeds are recorded in `boundary-notes.txt`, `errors-notes.txt`, and their `*-bounded-final*.log` files. They compare both implementations on the exact same tree pair to separate range correctness from parser variability.

The exact 69-test upstream command is saved in `run-upstream-final.sh`; it verifies that the copied upstream source matches the frozen bounded source, uses the temporary toolchain/caches, and runs Cargo offline with `--locked`, `--no-default-features`, and `--test-threads=1`.

Benchmark entry points:

```sh
EXPERIMENT_SHORT_CHARACTER=1 "$experiment/benchmark" \
  "$experiment/comparison-bounded-final.dylib"
EXPERIMENT_UTF16=1 EXPERIMENT_CALLBACK=1 \
  "$experiment/benchmark-wholesale" "$experiment/baseline.dylib" \
  "$experiment/baseline.dylib" "$experiment/comparison-bounded-final.dylib"
"$experiment/benchmark-hidden" "$experiment/baseline.dylib" \
  "$experiment/comparison-bounded-final.dylib"
```

The wholesale harness alternates forward/reverse engine order, has 12 post-warmup samples per engine/case, records wall and process CPU times, and checks exact ranges. Incremental timing orders are recorded in the corresponding JSON files and filename sequences. Diagnostic-library timings were never used as performance evidence.

Parser-fragility counterexample:

```sh
"$experiment/validate" "$experiment/baseline.dylib" \
  "$experiment/parse-only.dylib" 21 3 json
```

## Artifact ownership and archive readiness

All changed implementation sources are copied sources under this experiment root. Primary authored harnesses: `probe.c`, `benchmark.c`, `benchmark-wholesale.c`, `benchmark-hidden.c`, `benchmark-hidden-cpu.c`, `benchmark-adaptive-cutoff.c`, `validate.c`, `validate-included.c`, `validate-boundaries.c`, `validate-errors.c`; support files include `build.py`, `patch-comparison.py`, `run-upstream-final.sh`, generated hidden-depth grammar sources, variant patches, JSON reports, logs, and this handoff.

Frozen bounded artifacts and all earlier rejected evidence remain intact. `archive-handoff.json` and this document are the final disposition; older positive recommendations must not be read as current retention advice.

**Ready for archive. No further work is running or planned.**
