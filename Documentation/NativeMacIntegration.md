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
horizontal coordinate over vertical moves. When an adjacent vertical row is
outside the viewport, a command can request one bounded scroll and retry against
new, revision-checked geometry. A source caret that is already offscreen, a
clipped or unavailable destination, and an ambiguous wrap or bidi caret remain
unavailable. Horizontal movement can traverse individually representable hidden
whitespace in a left-to-right wrapped fragment, but a shared wrap boundary and
some RTL line transitions still require affinity. Visual word traversal has
128-step and 4,096-visible-UTF-16-unit limits.

Pointer selection can autoscroll from a viewport edge. Each tick obtains a new
input reservation and checks focus, selection, content and viewport identity.
A gesture gets at most 120 frames or two seconds, with a single start; mouse-up,
focus loss, detachment, pointer re-entry, stale state or lack of progress stops
it. Re-entering and then leaving again requires a new gesture to restart scrolling.
The wrapping view has no horizontal scrollable extent. A step limits its delta,
viewport size, nearby and prepared line lengths, total charged UTF-16 units and
layout calls, with a cooperative deadline. Its preflight checks a short buffer
around the current and target viewports; bounded layout can reuse a limited
number of cached, finished predecessors whose indexed heights still match.
A work-limit refusal that is revalidated before any scroll stops the timer
without reporting an uncertain input dispatch. Preflight does not guarantee that
every expensive preceding line is discovered before scrolling; actual layout
retains its independent work limits. A stale or reentrant state and an
interruption after scrolling remain uncertain and are never replayed. An
in-progress Core Text or AppKit call cannot be preempted. An interrupted layout
receives one separately bounded recovery; if that also fails, layout remains
unavailable until an independent viewport or content change.

The current selection contract carries a range, not a visual caret affinity. A
future revision-safe model must associate the active endpoint with its soft-wrap
side and its primary or secondary bidi caret side, and preserve or invalidate
that identity when selection, content or layout changes. Drawing, keyboard and
pointer navigation, input-method first-rect queries, accessibility geometry and
public selection state must all consume the same identity. Until that contract is
implemented, deterministic affinity and offscreen navigation gaps remain; these
are not claims of complete editor behavior. Active accessibility reports an
editable text role and routes supported setters through the input gate, but
role-change notifications and real VoiceOver behavior remain unverified.

## Foreground attachment evidence

Run `./script/build_and_run.sh --verify` on an unlocked Mac to build an isolated
AppKit test bundle and launch it as a foreground app. The runner requires every
selected test to execute and pass; a skipped key-window test is a failure. It
prints the retained temporary build and XCTest log locations. The project-local
Codex Run action invokes the same workflow, including the real-timer drag suite.

The app's foreground acceptance at framework revision `4081280f` found that an
ordinary 720×480 viewport could reject autoscroll before moving. A matching
short-line viewport fixture identified an overlarge preflight margin; repeated
steps also exposed redundant predecessor layout exhausting the existing work
budget. The bounded preflight and cached-predecessor changes now pass an
app-sized deterministic multi-step regression and a non-key-window integration
test using the production timer and uptime. That timer test injects focus and
cannot establish key-window behavior. The new foreground tests use the production
timer and app-sized scroll view, but their results must be recorded from an
unlocked session before treating the app's failure as resolved. Re-run the
app-owned acceptance after updating its framework pin.

A foreground run against the public attachment exercised first-responder
acquisition, blur and reacquisition, two-window transfer, synthetic key events,
contextual CRLF insertion, responder selection and undo/redo, synthetic mouse
click and drag with one controlled autoscroll tick, and copy/cut/paste using an
isolated named pasteboard. Direct `NSTextInputClient` calls exercised Unicode,
emoji, marked updates and commits, and composition discard on blur. Direct
`NSAccessibility` calls exercised the editable role, value, selection, range
and screen geometry. Gate contention and detached clients were also checked.
These are real key windows but synthetic events and direct protocol calls: they
do not establish physical keyboard, Emoji panel, third-party input method,
VoiceOver, real system-pasteboard integration or timing under live dragging.
The host app must integrate the tested framework revision and verify those
interactions in its own window before changing its disabled release gate.

After focus loss, reconstruction preserves a valid selection only when the
canonical revision and attributed snapshot still match; discarded marked text
restores its pre-composition selection under that same condition. A changed
snapshot, conflict or invalid Unicode/CRLF boundary resets the selection to the
start. This comparison and the existing reconstruction can scan the document;
no latency bound is claimed. AppKit Return currently inserts the contextual
line ending but has no language-aware automatic indentation or Markdown
continuation contract; those remain deterministic feature gaps.

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

On iOS, paste, arbitrary insertion, text replacement and Writing Tools preserve
supplied delimiters. UIKit's [`UIKeyInput.insertText(_:)`](https://developer.apple.com/documentation/uikit/uikeyinput/inserttext(_:))
provides a string but no per-insertion origin, and [custom keyboards can insert
arbitrary strings](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards).
An unmarked single LF can therefore be either Return or literal input. Paste
actions and marked text identify only those specific paths; input-delegate
notifications and expected input contexts cannot identify all remaining calls.
A generic LF remains literal, including when it commits marked text. This
changes the former `lineEndings` normalization behavior.

A source that actually identifies a Return command can synchronously invoke
`TextView.insertLogicalNewline()`. It resolves the surrounding or predominant
ending and uses the language indentation planner for every supported delimiter.
It rejects active composition and stale selection or document state; callers
must not retain and replay a command after its state changes. A delegate may
perform its own edit and reject the default edit, so a false result never
implies permission to insert a fallback LF. The app's existing Markdown
continuation is host-owned and scoped to its explicit logical-newline action;
it is not supplied by the framework's generic `insertText` path. UIKit
`UIKeyCommand` applies to hardware keyboards, and this framework does not
intercept Return ahead of the input system because that could interfere with
composition or the host continuation path.

Ordinary software-keyboard Return and unhandled hardware Return can consequently
still insert a literal LF in a CRLF or CR document and omit automatic indentation
and Markdown continuation. No public callback audited here safely distinguishes
those events from every literal input; solving them requires a genuinely
identified host/input-source command, not a heuristic based on LF, missing marked
text or a likely input device. Actual software and hardware keyboard, dictation,
accessibility and IME sequences remain to be verified interactively. Do not claim
full cross-platform keyboard compliance.

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
