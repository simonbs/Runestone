# Large-file performance checks

Generate 25 MiB documents and check scrolling, editing, syntax highlighting, and
rendering with wrapping enabled and disabled. Fixtures are generated in memory;
no large documents are committed.

With Xcode, `xcsift`, and an installed iOS simulator, run from the repository root:

```sh
git submodule update --init --recursive
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-performance
```

Use a new result directory each time. The script builds Release with testability
and coverage disabled, then runs serially. Expensive cases run only when
`RUNESTONE_PERFORMANCE=1` is set in the test runner. Ordinary test runs skip them.
Optional test identifiers after the result directory select a smaller set:

```sh
Scripts/run-large-file-performance.sh '<simulator UDID>' /tmp/runestone-correctness \
  RunestoneTests/LargeFileCorrectnessTests
```

The default run covers fourteen scrolling/editing scenarios, eight large-file
correctness scenarios, distributed traversal, first-viewport preparation, full-line
typesetting, and line indexing. Correctness checks include text, selection,
splitting/joining/deleting lines, undo/redo, highlighting, fresh-editor comparisons,
glyphs, caret geometry, pixels, and viewport coverage.

Timing excludes keyboard, persistence, and application callbacks. Display-link
intervals measure run-loop delivery rather than compositor hitches. Simulator
measurements do not establish physical-device frame rates. Raw samples and result
bundles stay in the supplied result directory.
