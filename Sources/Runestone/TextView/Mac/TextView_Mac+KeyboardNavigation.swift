#if os(macOS)
public extension TextView {
    /// Moves the insertion pointer backward in the current content.
    override func moveBackward(_ sender: Any?) {
        textViewController.locationNavigator.moveLeft()
    }

    /// Extends the selection to include the content before the current selection.
    override func moveBackwardAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveLeftAndModifySelection()
    }

    /// Moves the insertion pointer down in the current content.
    override func moveDown(_ sender: Any?) {
        textViewController.locationNavigator.moveDown()
    }

    /// Extends the selection to include the content below the current selection.
    override func moveDownAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveDownAndModifySelection()
    }

    /// Moves the insertion pointer forward in the current content.
    override func moveForward(_ sender: Any?) {
        textViewController.locationNavigator.moveRight()
    }

    /// Extends the selection to include the content below the current selection.
    override func moveForwardAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveRightAndModifySelection()
    }

    /// Moves the insertion pointer left in the current content.
    override func moveLeft(_ sender: Any?) {
        textViewController.locationNavigator.moveLeft()
    }

    /// Extends the selection to include the content to the left of the current selection.
    override func moveLeftAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveLeftAndModifySelection()
    }

    /// Moves the insertion pointer right in the current content.
    override func moveRight(_ sender: Any?) {
        textViewController.locationNavigator.moveRight()
    }

    /// Extends the selection to include the content to the right of the current selection.
    override func moveRightAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveRightAndModifySelection()
    }

    /// Move the insertion pointer to the beginning of the document.
    override func moveToBeginningOfDocument(_ sender: Any?) {
        textViewController.locationNavigator.moveToBeginningOfDocument()
    }

    /// Move the selection to include the beginning of the document.
    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToBeginningOfDocumentAndModifySelection()
    }

    /// Move the insertion pointer to the beginning of the line.
    override func moveToBeginningOfLine(_ sender: Any?) {
        textViewController.locationNavigator.moveToBeginningOfLine()
    }

    /// Move the selection to include the beginning of the line.
    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToBeginningOfLineAndModifySelection()
    }

    /// Move the insertion pointer to the beginning of the paragraph.
    override func moveToBeginningOfParagraph(_ sender: Any?) {
        textViewController.locationNavigator.moveToBeginningOfParagraph()
    }

    /// Move the selection to include the beginning of the paragraph.
    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToBeginningOfParagraphAndModifySelection()
    }

    /// Move the insertion pointer to the end of the document.
    override func moveToEndOfDocument(_ sender: Any?) {
        textViewController.locationNavigator.moveToEndOfDocument()
    }

    /// Move the selection to include the end of the document.
    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToEndOfDocumentAndModifySelection()
    }

    /// Move the insertion pointer to the end of the line.
    override func moveToEndOfLine(_ sender: Any?) {
        textViewController.locationNavigator.moveToEndOfLine()
    }

    /// Move the selection to include the end of the line.
    override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToEndOfLineAndModifySelection()
    }

    /// Move the insertion pointer to the end of the paragraph.
    override func moveToEndOfParagraph(_ sender: Any?) {
        textViewController.locationNavigator.moveToEndOfParagraph()
    }

    /// Move the selection to include the end of the paragraph.
    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveToEndOfParagraphAndModifySelection()
    }

    /// Moves the insertion pointer up in the current content.
    override func moveUp(_ sender: Any?) {
        textViewController.locationNavigator.moveUp()
    }

    /// Extends the selection to include the content above the current selection.
    override func moveUpAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveUpAndModifySelection()
    }

    /// Move the insertion point one word backward.
    override func moveWordBackward(_ sender: Any?) {
        textViewController.locationNavigator.moveWordLeft()
    }

    /// Extends the selection to include the word in the backward direction.
    override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveWordLeftAndModifySelection()
    }

    /// Move the insertion point one word forward.
    override func moveWordForward(_ sender: Any?) {
        textViewController.locationNavigator.moveWordRight()
    }

    /// Extends the selection to include the word in the forward direction.
    override func moveWordForwardAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveWordRightAndModifySelection()
    }

    /// Move the insertion point one word to the left.
    override func moveWordLeft(_ sender: Any?) {
        textViewController.locationNavigator.moveWordLeft()
    }

    /// Extends the selection to include the word to the left of the insertion pointer.
    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveWordLeftAndModifySelection()
    }

    /// Move the insertion point one word to the right.
    override func moveWordRight(_ sender: Any?) {
        textViewController.locationNavigator.moveWordRight()
    }

    /// Extends the selection to include the word to the right of the insertion pointer.
    override func moveWordRightAndModifySelection(_ sender: Any?) {
        textViewController.selectionNavigator.moveWordRightAndModifySelection()
    }
}
#endif
