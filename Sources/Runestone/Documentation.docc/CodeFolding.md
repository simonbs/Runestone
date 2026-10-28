# Code Folding

Learn how to collapse code blocks and Markdown sections using the gutter.

## Overview

Code folding lets you hide parts of a document while keeping the rest of the text visible. For example, you can collapse the body of a function or a section in a Markdown document.

Before reading this article, make sure that you have followed the guide on <doc:AddingATreeSitterLanguage>.

## Enabling Code Folding

Code folding is disabled by default. Enable it by setting <doc:TextView/isCodeFoldingEnabled> to `true`.

```swift
textView.isCodeFoldingEnabled = true
```

The language used by the text view must provide a folding query. Languages from the [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) package include this query when one is available.

Tap a chevron in the gutter to collapse or expand the lines below it. The line containing the chevron stays visible, including any wrapped text on that line. The folding controls are available even when line numbers are hidden.

Collapsing text does not change the document or add an undo operation. Copying and saving still include the hidden text, and line numbers continue to refer to the complete document. If you collapse a section that contains another collapsed section, the inner section stays collapsed when you expand its parent.

If collapsing a section would hide the selection, the selection moves to the line containing the chevron. Search and navigation to a hidden location expand the sections containing that location. Moving the cursor with the arrow keys skips collapsed text.

The text fades and slides when a section is collapsed or expanded. Near the bottom of a document, the text view waits for the transition to finish before adjusting its scroll position. These animations respect the system's Reduce Motion setting.

Folding is temporarily unavailable during a Writing Tools session. A section containing text being entered with an input method cannot be collapsed until composition finishes.

## Folding Markdown Sections

Markdown sections extend to the next heading of the same or a higher level. Both hash-prefixed headings and underline-style headings are supported. When you collapse an underline-style heading, only its first line stays visible. The underline and any additional lines of heading text are hidden with the section.

Code blocks inside a Markdown document can have their own folding controls. Provide their languages through <doc:TreeSitterLanguageProvider>, as described in <doc:AddingATreeSitterLanguage>.

## Adding a Folding Query

If you are adding a language manually, create an instance of <doc:TreeSitterLanguage/Query> with the folding query and pass it to the `foldsQuery` parameter when creating the language.

```swift
let foldsQuery = TreeSitterLanguage.Query(string: "(statement_block) @fold")
let language = TreeSitterLanguage(
    tree_sitter_javascript(),
    foldsQuery: foldsQuery
)
```

Folding queries use the `@fold` capture to identify parts of the syntax tree that can be collapsed. For example, a JavaScript query can capture statement blocks:

```scheme
(statement_block) @fold
```

Queries are usually stored in a file named `folds.scm`. To load a query from a file, pass its URL to `TreeSitterLanguage.Query(contentsOf:)`.

Runestone keeps the first line of a capture visible and hides the following lines. Repeated captures in the same match, such as a group of consecutive imports, form a single section.

Folding queries can use `#trim!`, `#offset!`, `#has-parent?`, and `#not-has-parent?` in addition to the text predicates supported by Runestone. If a query inherits another query using a `; inherits:` comment, combine the query files before passing them to Runestone.

For Markdown, use `@fold.heading` to capture `atx_heading` and `setext_heading` nodes. Runestone uses their heading levels to find the end of each section. Headings inside a block quote or list item belong to that container and do not end sections outside it.

Runestone updates the available sections as the text changes. Editing the start or end of a collapsed section can expand it. Replacing the document, changing its language, or disabling folding clears the collapsed sections.
