# ``Runestone/TextView``

## Topics

### Initialing the Text View

- ``init()``
- ``init(frame:)``
- ``init(coder:)``

### Lifecycle

- ``isFlipped``
- ``didMoveToWindow()``
- ``layoutSubviews()``
- ``safeAreaInsetsDidChange()``
- ``traitCollectionDidChange(_:)``
- ``viewDidMoveToWindow()``
- ``resizeSubviews(withOldSize:)``
- ``layoutSubtreeIfNeeded()``
- ``resetCursorRects()``

### Responding to Text View Changes

- ``editorDelegate``
- ``TextViewDelegate``

### Configuring the Appearance

- ``theme``
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
- ``lengthOfInitallyLongestLine``

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
- ``gutterMinimumCharacterCount``

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
- ``showMenuAfterNavigatingToHighlightedRange``

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
- ``text(in:)``
- ``insertText(_:)``
- ``insertText(_:replacementRange:)``
- ``insertNewline(_:)``
- ``insertTab(_:)``
- ``replaceText(in:)``
- ``replace(_:withText:)-7gret``
- ``deleteForward(_:)``
- ``deleteBackward()``
- ``deleteBackward(_:)``
- ``undoManager``
- ``undo(_:)``
- ``redo(_:)``

### Managing the Keyboard

- ``keyboardAppearance``
- ``keyboardType``
- ``returnKeyType``
- ``inputAccessoryView``

### Selecting Text

- ``selectedRange``
- ``selectedRange()``
- ``selectedTextRange``
- ``selectionBarColor``
- ``selectionHighlightColor``

### Scrolling

- ``contentOffset``
- ``isAutomaticScrollEnabled``

### Keyboard Events

- ``keyDown(with:)``

### Keyboard Navigation

- ``moveBackward(_:)``
- ``moveBackwardAndModifySelection(_:)``
- ``moveDown(_:)``
- ``moveDownAndModifySelection(_:)``
- ``moveForward(_:)``
- ``moveForwardAndModifySelection(_:)``
- ``moveLeft(_:)``
- ``moveLeftAndModifySelection(_:)``
- ``moveRight(_:)``
- ``moveRightAndModifySelection(_:)``
- ``moveToBeginningOfDocument(_:)``
- ``moveToBeginningOfDocumentAndModifySelection(_:)``
- ``moveToBeginningOfLineAndModifySelection(_:)``
- ``moveToBeginningOfLine(_:)``
- ``moveToBeginningOfLineAndModifySelection(_:)``
- ``moveToBeginningOfParagraph(_:)``
- ``moveToBeginningOfParagraphAndModifySelection(_:)``
- ``moveToEndOfDocument(_:)``
- ``moveToEndOfDocumentAndModifySelection(_:)``
- ``moveToEndOfLine(_:)``
- ``moveToEndOfLineAndModifySelection(_:)``
- ``moveToEndOfParagraph(_:)``
- ``moveToEndOfParagraphAndModifySelection(_:)``
- ``moveUp(_:)``
- ``moveUpAndModifySelection(_:)``
- ``moveWordBackward(_:)``
- ``moveWordBackwardAndModifySelection(_:)``
- ``moveWordForward(_:)``
- ``moveWordForwardAndModifySelection(_:)``
- ``moveWordLeft(_:)``
- ``moveWordLeftAndModifySelection(_:)``
- ``moveWordRight(_:)``
- ``moveWordRightAndModifySelection(_:)``

### Mouse Events

- ``mouseDown(with:)``
- ``mouseDragged(with:)``
- ``mouseUp(with:)``
- ``rightMouseDown(with:)``

### Interactions

- ``hitTest(_:with:)``
- ``pressesEnded(_:with:)``

### Commands

- ``cut(_:)``
- ``copy(_:)``
- ``paste(_:)``
- ``selectAll(_:)``
- ``replace(_:withText:)-7cbas``
- ``canPerformAction(_:withSender:)``
- ``deleteWordForward(_:)``
- ``deleteWordBackward(_:)``

### Responder Chain

- ``canBecomeFirstResponder``
- ``acceptsFirstResponder``
- ``becomeFirstResponder()``
- ``resignFirstResponder()``
- ``validateMenuItem(_:)``

### Text Input Conformance

- ``inputDelegate``
