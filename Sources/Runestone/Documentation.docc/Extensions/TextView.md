# ``Runestone/TextView``

## Topics

### Initialing the Text View

- ``init(frame:)``
- ``init(coder:)``

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
- ``lineBreakMode``

### Invisible Characters

- ``showSpaces``
- ``showNonBreakingSpaces``
- ``showTabs``
- ``showLineBreaks``
- ``showSoftLineBreaks``
- ``spaceSymbol``
- ``nonBreakingSpaceSymbol``
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

### Line Endings

- ``lineEndings``

### Overscroll

- ``verticalOverscrollFactor``
- ``horizontalOverscrollFactor``

### Page Guide

- ``showPageGuide``
- ``pageGuideColumn``

### Navigation

- ``TextLocation``
- ``textLocation(at:)``
- ``location(at:)``
- ``goToLine(_:select:)``
- ``GoToLineSelection``
- ``moveSelectedLinesUp()``
- ``moveSelectedLinesDown()``
- ``scrollRangeToVisible(_:)``

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

### Supporting Find and Replace

- ``isFindInteractionEnabled``
- ``findInteraction``
- ``search(for:)``
- ``search(for:replacingMatchesWith:)``
- ``textPreview(containing:)``

### Editing

- ``isEditable``
- ``isSelectable``
- ``isEditing``
- ``text``
- ``autocapitalizationType``
- ``autocorrectionType``
- ``spellCheckingType``
- ``smartDashesType``
- ``smartInsertDeleteType``
- ``smartQuotesType``
- ``text(in:)-3lp4v``
- ``text(in:)-3wzco``
- ``insertText(_:)``
- ``replaceText(in:)``
- ``replace(_:withText:)-7gret``
- ``replace(_:withText:)-7ugo8``
- ``deleteBackward()``
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

### Laying Out Subviews

- ``layoutSubviews()``
- ``safeAreaInsetsDidChange()``

### Responder Chain

- ``canBecomeFirstResponder``
- ``becomeFirstResponder()``
- ``resignFirstResponder()``

### UITextInput Conformace

- ``hasText``
- ``beginningOfDocument``
- ``endOfDocument``
- ``markedTextRange``
- ``tokenizer``
- ``textRange(from:to:)``
- ``position(from:offset:)``
- ``position(from:in:offset:)``
- ``position(within:farthestIn:)``
- ``closestPosition(to:)``
- ``closestPosition(to:within:)``
- ``compare(_:to:)``
- ``offset(from:to:)``
- ``characterRange(at:)``
- ``characterRange(byExtending:in:)``
- ``caretRect(for:)``
- ``firstRect(for:)``
- ``selectionRects(for:)``
