# Code Folding

Enable gutter disclosures for code blocks and Markdown sections.

## Overview

Folding is disabled by default. Set ``TextView/isCodeFoldingEnabled`` to `true`
and use a language with a ``TreeSitterLanguage/foldsQuery``:

```swift
textView.isCodeFoldingEnabled = true
```

Folding controls occupy their own gutter column and work with line numbers shown
or hidden. Tap a disclosure to collapse or expand the following lines. Wrapped
headers remain visible in full. Markdown sections keep their first logical line
and hide subsequent lines, including Setext underlines and multiline title continuations.

Collapsing affects presentation only. Source offsets, logical line numbers,
copying, saving, and the text undo history continue to describe the complete
document. Collapsed child folds retain their state when a parent is reopened.
If the selection would be hidden by a collapse, it moves to the header first.
Navigation to a hidden destination, including search and go-to-line, expands its
enclosing folds. Arrow movement skips collapsed lines. Disclosures do not hide
marked text during composition or change folds during an active Writing Tools session.

Folded rows fade in place while following rows slide to their new positions.
Near the bottom of a document, the scrollable height is retained until the fold
finishes, then the viewport settles into the remaining content.
Transitions respect Reduce Motion. Scrolling, edits,
or another fold action finish the previous transition at its committed layout.
Hidden lines keep their measured or estimated heights and are skipped during
layout; expanding a large block prepares the viewport rather than the whole block.

## Folding Queries

The optional `foldsQuery` initializer argument accepts a Tree-sitter query using
the `folds.scm` / `@fold` convention:

```scheme
[
  (function_definition)
  (class_definition)
] @fold
```

Each multiline capture preserves its first logical line and hides its subsequent
lines. Repeated captures within one match, such as consecutive imports, become a
single range. The folding reader supports `#trim!`, `#offset!`, `#has-parent?`, and
`#not-has-parent?` in addition to Runestone's existing text predicates. Query
inheritance comments must be resolved into the supplied query by the language
package.

Runestone also recognizes `@fold.heading` on Markdown `atx_heading` and
`setext_heading` nodes. It derives sections from heading levels up to the next
equal-or-higher heading within the same document, block quote, or list item.
This handles mixed heading styles in grammars whose `section` nodes represent
only hash-prefixed headings. Fenced-code contents can supply additional folds
through ``TreeSitterLanguageProvider``.

Queries run against copied syntax trees in the background. Edits supersede older
results and translate unaffected collapsed ranges while fresh candidates are
computed. Editing a fold boundary can expand that fold; replacing the document,
changing its language, or disabling folding clears collapsed state.
