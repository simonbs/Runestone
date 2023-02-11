#if os(macOS)
import Foundation

extension TextViewController {
    func moveLeftAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .character, inDirection: .backward)
    }

    func moveRightAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .character, inDirection: .forward)
    }

    func moveUpAndModifySelection() {
        move(by: .line, inDirection: .backward)
    }

    func moveDownAndModifySelection() {
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeftAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .word, inDirection: .backward)
    }

    func moveWordRightAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLineAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLineAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraphAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraphAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocumentAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocumentAndModifySelection() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .document, inDirection: .forward)
    }

    func startDraggingSelection(from location: Int) {
        selectedRange = selectionService.rangeByStartDraggingSelection(from: location)
    }

    func extendDraggedSelection(to location: Int) {
        selectedRange = selectionService.rangeByExtendingDraggedSelection(to: location)
    }

    func selectWord(at location: Int) {
        selectedRange = selectionService.rangeBySelectingWord(at: location)
    }

    func selectLine(at location: Int) {
        selectedRange = selectionService.rangeBySelectingLine(at: location)
    }
}

private extension TextViewController {
    private func move(by granularity: TextGranularity, inDirection direction: TextDirection) {
        if let selectedRange {
            self.selectedRange = selectionService.range(moving: selectedRange, by: granularity, inDirection: direction)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        if let selectedRange {
            self.selectedRange = selectionService.range(moving: selectedRange, toBoundary: boundary, inDirection: direction)
        }
    }
}
#endif
