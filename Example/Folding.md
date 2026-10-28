# Code folding in the Example

Open the ellipsis menu and choose **Folding Examples → JavaScript Folding Example**
or **Markdown Folding Example**. Choosing a sample explicitly enables Code Folding
and line numbers. Tap the chevrons in the gutter to collapse or expand a block.

The **Code Folding** menu setting is persisted and is off by default. Applications
opt in with `textView.isCodeFoldingEnabled = true`. The Markdown sample also supplies
JavaScript and Markdown-inline languages for fenced-code and inline parsing.

The app remembers the selected sample language when saving edited text. Loading a
local navigation fixture whose extension is `.md` or `.markdown` selects Markdown.
The companion language package is pinned to the `codex/code-folding-queries` branch;
its folding-query provenance and adaptations are documented in that repository.

## Validation

The complete 330-test Runestone unit suite passed. After the final disabled-feature
fast paths, all 35 affected folding, parser, movement, and viewport tests passed.
The folding cases cover nested state, editing and undo, CRLF/EOF navigation,
reentrant delegates, destination reveal, source selection, and a 10,000-line
collapsed range whose hidden lines never acquire layout controllers.

The Release Example was exercised on an isolated iPhone 17 simulator running
iOS 26.5. Real gutter taps collapsed and reopened JavaScript blocks, Markdown
sections, Setext headings, and fenced code. Parent reopening retained collapsed
children. Disclosures remained usable with line numbers hidden, and disabling
folding restored the document. Local recordings were inspected for transition
and settled-layout defects; these captures are not appearance regression tests.

Discovery currently queries all fold-enabled trees in the background after edits,
with cooperative cancellation and revision checks. Folding a cached range does
not reparse or measure its hidden lines. Physical-device frame timing and sustained
large-document editing performance remain unmeasured.
