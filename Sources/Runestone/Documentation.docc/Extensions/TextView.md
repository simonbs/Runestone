# ``Runestone/TextView``

## Topics

### Initialing the Text View

- ``init(frame:)``

### Responding to Text View Changes

- ``editorDelegate``
- ``TextViewDelegate``

### Configuring the Appearance

- ``theme``
- ``backgroundColor``
- ``kern``
- ``lineHeightMultiplier``
- ``insertionPointColor``
- ``selectionBarColor``
- ``selectionHighlightColor``
- ``textContainerInset``
- ``Theme``

### Syntax Highlighting

- ``setLanguageMode(_:completion:)``
- ``setState(_:addUndoAction:)``
- ``syntaxNode(at:)``
- ``redisplayVisibleLines()``
- ``TextViewState``

### Line Selection

- ``lineSelectionDisplayType``

### Line Wrapping

- ``isLineWrappingEnabled``
- ``lengthOfInitallyLongestLine``

### Invisible Characters

- ``showSpaces``
- ``showTabs``
- ``showLineBreaks``
- ``showSoftLineBreaks``
- ``spaceSymbol``
- ``tabSymbol``
- ``lineBreakSymbol``
- ``softLineBreakSymbol``

### Line Numbers

- ``showLineNumbers``

### Gutter

- ``gutterLeadingPadding``
- ``gutterTrailingPadding``
- ``gutterWidth``

### Character Pairs

- ``characterPairs``
- ``characterPairTrailingComponentDeletionMode``

### Overscroll

- ``verticalOverscrollFactor``
- ``horizontalOverscrollFactor``

### Page Guide

- ``showPageGuide``
- ``pageGuideColumn``

### Navigation

- ``textLocation(at:)``
- ``TextLocation``
- ``goToLine(_:select:)``
- ``GoToLineSelection``

### Indenting Text

- ``shiftLeft()``
- ``shiftRight()``
- ``isIndentation(at:)``
- ``detectIndentStrategy()``
- ``indentStrategy``
- ``IndentStrategy``

### Highlighting Text Ranges

- ``highlightedRanges``
- ``highlightedRangeLoopingMode``
- ``selectNextHighlightedRange()``
- ``selectPreviousHighlightedRange()``
- ``selectHighlightedRange(at:)``

### Search and Replace

- ``search(for:)``
- ``search(for:replacingMatchesWith:)``
- ``textPreview(containing:)``

### Editing

- ``isEditing``
- ``text``
- ``autocapitalizationType``
- ``autocorrectionType``
- ``spellCheckingType``
- ``smartDashesType``
- ``smartInsertDeleteType``
- ``smartQuotesType``
- ``text(in:)``
- ``insertText(_:)``
- ``replaceText(in:)``
- ``replace(_:withText:)-7gret``
- ``replace(_:withText:)-7ugo8``
- ``undoManager``

### Managing the Keyboard

- ``keyboardAppearance``
- ``keyboardType``
- ``returnKeyType``
- ``inputAccessoryView``
- ``inputAssistantItem``
- ``reloadInputViews()``

### Selecting Text

- ``selectedRange``
- ``selectedTextRange``
- ``selectionBarColor``
- ``selectionHighlightColor``

### Scrolling

- ``contentOffset``
- ``isAutomaticScrollEnabled``
- ``automaticScrollInset``

### Laying Out Subviews

- ``layoutSubviews()``
- ``safeAreaInsetsDidChange()``

### Responder Chain

- ``canBecomeFirstResponder``
- ``becomeFirstResponder()``
- ``resignFirstResponder()``
- ``canPerformAction(_:withSender:)``
