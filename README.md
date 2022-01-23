![](https://github.com/simonbs/Runestone/raw/main/Sources/Runestone/Documentation.docc/Resources/hero.png)

### Welcome to Runestone - a code editor for iOS with focus on performance

Runestone uses GitHub's [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) to parse code to a syntax tree which is used for features that require an understanding of the code in the editor, for example syntax highlighting.

## Features

- Syntax highlighting using [Tree-sitter's captures](https://tree-sitter.github.io/tree-sitter/syntax-highlighting#highlights).
- Line numbers.
- Show invisible characters (tabs, spaces and line breaks).
- Insertion of character pairs, e.g. inserting the trailing quotation mark when inserting the leading.
- Customization of colors and fonts using the [Theme](https://github.com/simonbs/Runestone/blob/main/Sources/Runestone/TextView/Theme.swift) protocol.
- Toggle line wrapping on and off.
- Adjust line heights. 
- Add a page guide.
- Automatically detects if a file is using spaces or tabs for indentation.

## Getting Started

Please refer to the [Getting Started](https://docs.runestone.app/documentation/runestone/gettingstarted) article in the documentation.

## Documentation

The documentation os all public types is available at [docs.runestone.app](https://docs.runestone.app). The documentation is generated from the Swift code using Apple's [DocC documentation compiler](https://developer.apple.com/documentation/docc).

## Performance

Runestone was built to be fast. It's good performance is by far mostly thanks to Tree-sitter's incremental parsing and [AvalonEdit's approach for managing lines in a document](https://github.com/icsharpcode/AvalonEdit/blob/master/ICSharpCode.AvalonEdit/Document/DocumentLineTree.cs).

When judging the performance of Runestone, it is key to build your app in the release configuration. The optimizations applied by the compiler when using the release configuration becomes very apparent when opening large documents.

## Acknowledgments

- [Tree-sitter](https://tree-sitter.github.io/tree-sitter) is used to parse code incrementally.
- Line management is translated to Swift from [AvalonEdit](https://github.com/icsharpcode/AvalonEdit).
- [swift-tree-sitter](https://github.com/viktorstrate/swift-tree-sitter) and [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) which have served as inspiration for the Tree-sitter bindings.
- Detection of indent strategy inspired by [auto-detect-indentation](https://github.com/jtokoph/auto-detect-indentation).
- And last (but not least!), thanks a ton to [Alexander Blach](https://twitter.com/Lextar) (developer of [Textastic](https://www.textasticapp.com)), [Till Konitzer](https://twitter.com/knutknatter) (developer of [Essayist](https://www.essayist.app)), [Greg Pierce](https://twitter.com/agiletortoise) (developer of [Drafts](https://getdrafts.com)) and [Max Brunsfeld](https://twitter.com/maxbrunsfeld) (developer of [Tree-sitter](https://tree-sitter.github.io/tree-sitter/)) for pointing me in the right direction when I got stuck.
