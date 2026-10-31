# Native Mac integration: dependency and scale evidence

This is the Runestone-side counterpart to RunestoneEditor's
`Documentation/NativeMacDependencyAndScaleEvidence.md` at app revision
`0eb07a52cfeb7059ed3fbf385cab691cb928686c`. It records the reviewed capability
boundary and outstanding evidence; it is not a Phase 1 exit or release claim.
The app's local framework revision pin for that historical evidence was
`b73f673e73c9e3380a1cee3899aabc1016e49496`. The recorded audit applies to that
pin, not subsequent framework changes. The app worktree was later observed at
`94236e9b1fb8ec22d1a65e285fa91a52be1226c4`, with its revision file pinning
`d1b5ea3f86fb962a92d274a50d855be4c9a1fc27`; the interaction work is newer than
that pin. The current framework HEAD and queue owner are recorded separately in
the integration queue. The committed remote
dependency lock is a separate input and has not been updated by this work.

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
The opt-in `RunestoneEditableDocumentAttachment` creates and owns a fresh input
view and exposes its revision-checked input state. The app installs that view
and explicitly requests first-responder status; construction does not focus it.
Detach immediately disarms it and may require retry while the context and gate
quiesce. The host owns its bridge and lifetime and must retain the attachment
until detach completes. The document view does not become reusable as an
editable attachment. The observed app has a disabled-by-default editable gate
and otherwise hosts the read-only view; keep its release gate disabled until
real focus, keyboard, input-method and accessibility
interaction have been verified. Focus eligibility is revoked on focus or key-window
loss, and the host must explicitly request it again. Detach does not transfer the
window's first responder; the host owns that transition.

The prepared command set includes plain-text copy/cut/paste, word movement and
deletion, visual horizontal/vertical movement, line/document/paragraph edges,
extended selection, Select All, newline and line break. Copy/cut validate the
selected UTF-16 boundaries; paste retains its exact text and line endings.
Pasteboard callouts and child-gate admission recheck focus and revision. A cut
writes the pasteboard before deleting; failures after the write are uncertain
and are never replayed. Menu validation disables unsupported or unavailable
commands. The app must implement `canPerformInputHistory` as well as the
existing history operation for Undo/Redo menu validation; its default is false.

Visual navigation uses the current Core Text viewport and preserves a preferred
horizontal coordinate over vertical moves. It rejects clipped or unavailable
geometry and ambiguous bidi caret affinity rather than guessing. Horizontal
movement across a wrapped fragment and some RTL line boundaries is unavailable
until affinity is represented. Visual word traversal has explicit 128-step and
4,096-visible-UTF-16-unit limits. Pointer drags clamp to already laid-out viewport
edges; offscreen autoscroll is not implemented. These are deterministic gaps,
not claims of complete editor behavior. Active accessibility reports an editable
text role and routes supported setters through the input gate, but role-change
notifications and real VoiceOver behavior remain unverified.

## Input contention and recovery plan

The internal input adapter reports whether each failed callback was rejected
before admission or may have taken effect. A pre-admission `notApplied` result
applies only to that callback; it says nothing about the rest of an input-method
event and does not authorize replay. An admitted failure or interrupted driver
dispatch can follow publication and is reported as `mayHaveApplied`. Recognized
commands that cannot run are reported instead of being forwarded as unrelated
commands. No text, selection payload or event is retained or replayed.

The private connection keeps the first 16 failure records in order and counts
additional records, saturating at the integer limit. Its weak observer is
notified after input activity becomes idle; the owner must call
`takeInputFailures()` to acknowledge the batch. Reset reports discarded
provisional composition, including an empty marked range. Once the old client
has been detached, callbacks to that retired client are inert and cannot be
reported. These reports provide detection, not automatic recovery.

`RunestoneInputDispatchHost` is an opt-in public capability for a future host.
Its parent dispatch reservation excludes competing document operations while
permitting sequential child reservations at the currently installed revision.
The private responder holds that parent over both input-driver handling and
key-binding fallback. Later input-client callbacks acquire their own scope;
they are not attributed to the earlier dispatch. The host synchronously
acknowledges metadata-only completion after each attempt, including rejection,
or a separate composition-discard notice. It may retain results in its own
bounded storage. A nested rejected attempt can complete while its outer dispatch
still holds the gate; callbacks arrive in completion order and must not call out.
A single pending history request retains metadata only; later input is rejected
until it has been resolved, and no input event is replayed. Delivery cannot be
guaranteed after the host or its source view has gone away.

The observed app host implements the parent/child dispatch and history hooks,
and its editable attachment integration is behind a disabled release gate. The
framework queues a history command until the enclosing dispatch closes; the host
must atomically check its captured revision under the document gate and handle
uncertain history outcomes. A completed synchronous dispatch means no failure
was detected, not that an IME will issue no later callbacks or that a canonical
edit occurred.
Before enabling the app's editing gate, define owner-visible recovery and
feedback for failed input and discarded composition, integrate and verify the
app host, and verify actual key focus, input methods, composition on blur,
accessibility and VoiceOver in an unlocked session. Never replay stale input
against a newer snapshot. The headless tests do not establish those interactions.

## Line-ending editing contract

`RunestoneLineEndingPolicy` resolves an explicitly identified logical newline
against the UTF-16 document snapshot and replacement range. Matching nearest
unselected delimiters, or the only surrounding delimiter, determine the style;
conflicting neighbors use a unique document-wide predominant style, and a tie
or an empty document falls back to LF. CRLF is one delimiter; CR, LF, NEL,
Unicode line separator and paragraph separator are distinct. The policy rejects
ranges that split a surrogate pair or CRLF and never rewrites the snapshot.
Finding a delimiter may scan a long line, and ambiguous context may scan the
whole document; there is no incremental count or latency claim.

The private AppKit adapter resolves `insertNewline:` after the document gate is
held and the installed revision has been checked. `insertLineBreak:` inserts
the explicit Unicode line separator. Ordinary input-client text, marked updates,
commits and paste-like replacements remain literal; an ambiguous single LF is
not treated as proof of a command. The app's future gate implementation must
keep its snapshot and revision paired, preserve exact encoding and line endings
through publication and undo/redo, and route only reliably identified newline
commands through the contextual policy. The app's editable release gate remains disabled.

On iOS, paste, arbitrary insertion, text replacement and Writing Tools now
preserve supplied delimiters; callers can use `TextView.insertLogicalNewline()`
when they know an input was a newline command. This changes the former
`lineEndings` normalization behavior. UIKit's generic `insertText` does not
itself establish that a bare LF represents Return, so it remains literal and
does not run the old automatic-newline indentation path. Until the app has a
reliably identified command path, ordinary iOS keyboard Return can therefore
insert LF in a CRLF or CR document and omit automatic newline indentation.
Resolving and testing that integration, including real software keyboards and
IMEs, remains required; do not claim full cross-platform keyboard compliance.

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
