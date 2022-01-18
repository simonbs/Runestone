# ``Runestone``

Performant code editor with syntax highlighting, line numbers, invisible characters and much more.

## Overview

Runestone provides a text view with support for features commonly found in code editors. This includes the following list of features.

- Syntax highlighting.
- Line numbers.
- Show invisible characters.
- Highlight select line.
- Enable/disable line wrapping.
- Adjust line height and kerning.
- Search and replace with support for regular expression.
- Indent on line break.
- Show page guide.
- Handling of character like quotes and brackets.

The text view provided by Runestone does not subclass UITextView but has an API that is similar to the one of UITextView.

The framework is [available on GitHub](https://github.com/simonbs/runestone).

![](hero.png)

## Topics

### Essentials

- <doc:GettingStarted>
- ``TextView``
- ``TextViewDelegate``
- ``TextViewState``

### Syntax Highlighting

Syntax highlighting is based on GitHub's [Tree-sitter](https://github.com/tree-sitter/tree-sitter) parser generator. It has support for most popular programming languages.

- <doc:AddingATreeSitterLanguage>
- <doc:UnderstandingCaptureSequences>
- ``Theme``
- ``FontTraits``
- ``LanguageMode``
- ``PlainTextLanguageMode``
- ``TreeSitterLanguageMode``
- ``TreeSitterLanguage``
- ``TreeSitterLanguageProvider``
- ``SyntaxNode``

### Selected Line

Highlight selected the line containing the caret.

- ``LineSelectionDisplayType``

### Indentation

Automatically indent when inserting a new line break.

- ``IndentStrategy``
- ``DetectedIndentStrategy``
- ``TreeSitterIndentationScopes``

### Search and Replace

Search the text for queries and replace matches with a string. Supports regular expressions.

- ``SearchQuery``
- ``SearchResult``
- ``SearchReplaceResult``
- ``BatchReplaceSet``
- ``HighlightedRange``
- ``HighlightedRangeLoopingMode``
- ``TextPreview``

### Character Pairs

Automatically insert and delete closing the closing component of a character pair such as quotes and brackets.

- ``CharacterPair``
- ``CharacterPairTrailingComponentDeletionMode``

### Navigation

- ``GoToLineSelection``
- ``LinePosition``
