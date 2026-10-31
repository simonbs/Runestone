# Native Mac integration: dependency and scale evidence

This is the Runestone-side counterpart to RunestoneEditor's
`Documentation/NativeMacDependencyAndScaleEvidence.md` at app revision
`f69a24f5028817b35fc43e385f9c437c2de52f1a`. It records the reviewed capability
boundary and outstanding evidence; it is not a Phase 1 exit or release claim.
The app's local framework revision pin for that evidence is
`1c02a94658ad3bedf6048e1bcf979232df8a1e85`. That revision is the reviewed
framework source baseline; later changes to this note and test fixtures do not
change the exported products or runtime capabilities. The current framework
HEAD and queue owner are recorded separately in the integration queue. The
committed remote dependency lock is a separate input and has not been updated
by this work.

## Products and ownership

| Runestone package product | Platform and role | Audited Mac app graph |
| --- | --- | --- |
| `Runestone` | UIKit-based iOS editor; depends on `RunestoneEngine` and `TreeSitter`. | Not linked. |
| `RunestoneEngine` | Shared line storage, folding projection, Core Text layout and geometry primitives. | Transitive dependency of `RunestoneAppKit`. |
| `RunestoneAppKit` | AppKit/Core Text read-only document view, rendering helpers, and document-host gate protocols, bridge and lifetime. | Directly selected by the Mac app. |
| `TreeSitter` | C Tree-sitter library. | Not linked. |

The framework package declares iOS 14 and macOS 26 minimums; the `Runestone`
editor itself remains UIKit-based. The pinned `tree-sitter` submodule at the
reviewed baseline is `10eb5ac119eec9cb4267a8e035066473983f5f3a`.

The app's remaining directly selected products are `ThemeModel`,
`StandardThemes`, `PlainTextContent`, `ReviewPrompt`, `SourcePrinting`,
`TextEncodingModel`, and `DocumentOpenPolicy`. `StandardThemes` includes its
resource bundle, while `ReviewPrompt` depends on `AppEventsStore` and
`AppInfoStore`. The app evidence records one specific unsigned universal
Release build and its reviewed target/link closure. It is not evidence about
other configurations, runtime-loaded code, signing, distribution or Rosetta
execution.

`ReadOnlyDocumentView` exposes a read-only wrapping snapshot and conservative
accessibility text/geometry. `RunestoneInputDocumentHost`, its reservation and
publication protocols, `RunestoneInputDocumentBridge`, and
`RunestoneInputDocumentLifetime` expose a document-owned integration contract.
They do not provide an editable view. The prepared attachment, input client,
responder, commands and selection state remain internal; there is no public
editable attachment or selection API. The app currently hosts the read-only
view. Do not enable editing until input event contention/reset and composition
on blur have safe behavior, and real focus, input-method and accessibility
interaction have been verified.

## Scale evidence and remaining work

The app's deterministic 10,000,000-byte UTF-8/CRLF fixture has 10,000 lines of
1,000 bytes and SHA-256
`4780b5fa83919bfdac0380a9528752e19db5ce3d54c7f1eb9d8a5875a25e57ec`.
Its document test checks strict decoding and unchanged output bytes only; it
does not test URL warnings, file I/O, view layout or performance. The framework
viewport fixture separately checks that a distant viewport in a large
short-line document does not prepare the whole document. Its operation bound
begins after the line manager rebuild; it makes no claim that initial snapshot
copying, line indexing, reconstruction, or one very long wrapped line is
bounded independently of document length.

The existing iOS `Example/LargeFilePerformance.md` scenarios include large,
wrapped and highlighted inputs; their timed runs disable folding. They are not
Mac baselines. Representative small, large, long wrapped, highlighted and
folded Mac scenarios, release-configuration measurements, memory/latency
baselines and agreed tolerances remain open. Headless measurements may help
isolate work, but representative interactive focus/IME, scrolling, VoiceOver
and window behavior require an unlocked session; do not label a deterministic
fixture or a correctness test as a performance result. Full iOS regression,
actual IME and VoiceOver, Intel/Rosetta and distribution verification also
remain open.
