# Runestone

Welcome to Runestone - a code editor for iOS with focus on performance.

Runestone uses GitHub's [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) to parse code to a syntax tree which is used for features that require an understanding of the code in the editor, for example syntax highlighting.

## Features

- Syntax highlighting using [Tree-sitter's captures](https://tree-sitter.github.io/tree-sitter/syntax-highlighting#highlights).
- Line numbers.
- Show invisible characters (tabs, spaces and line breaks).
- Insertion of character pairs, e.g. inserting the trailing quotation mark when inserting the leading.
- Customization of colors and fonts using the [EditorTheme protocol](https://github.com/simonbs/Runestone/blob/main/Sources/Runestone/Editor/EditorTheme.swift).

### Wishlist

- [ ] Indentation when adding new lines
- [ ] Setting to adjust line spacing
- [ ] Setting to indent using spaces instead of tabs
- [ ] Search and replace
- [ ] Disable text wrapping

## Performance

Runestone was built to be fast. Its good performance is by far mostly thanks to [Tree-sitter's incremental parsing](https://tree-sitter.github.io/tree-sitter/), [AvalonEdit's approach for managing lines in a document](https://github.com/icsharpcode/AvalonEdit/blob/master/ICSharpCode.AvalonEdit/Document/DocumentLineTree.cs) and the fact that the NSTextStorage subclass is written in Objective-C ([SR-6197](https://bugs.swift.org/plugins/servlet/mobile#issue/SR-6197)).

When judging the performance of Runestone, it is key to build the app in the release configuration. The optimazations applied by the compiler when using the release configuration becomes very apparent when opening large documents.

## Acknowledgments

- [Tree-sitter](https://tree-sitter.github.io/tree-sitter) is used to parse code incrementally.
- Line management is translated to Swift from [AvalonEdit](https://github.com/icsharpcode/AvalonEdit). Also thanks to [Alexander Blach](https://twitter.com/Lextar) (developer of [Textastic](https://www.textasticapp.com)) for pointing me in the right direction.
- [swift-tree-sitter](https://github.com/viktorstrate/swift-tree-sitter) which Runestone's Swift bindings for Tree-sitter is heavily inspired by.
- The [Tomorrow](https://github.com/chriskempson/tomorrow-theme), [Solarized](https://ethanschoonover.com/solarized/), [Gruvbox](https://github.com/morhetz/gruvbox) and [Sundell's Colors](https://github.com/JohnSundell/XcodeTheme) themes included in the example project.
