#if os(macOS)
import Foundation

extension TextViewController {
    func moveLeftAndModifySelection() {
        move(by: .character, inDirection: .backward)
    }

    func moveRightAndModifySelection() {
        move(by: .character, inDirection: .forward)
    }

    func moveUpAndModifySelection() {
        move(by: .line, inDirection: .backward)
    }

    func moveDownAndModifySelection() {
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeftAndModifySelection() {
        move(by: .word, inDirection: .backward)
    }

    func moveWordRightAndModifySelection() {
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLineAndModifySelection() {
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLineAndModifySelection() {
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraphAndModifySelection() {
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraphAndModifySelection() {
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocumentAndModifySelection() {
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocumentAndModifySelection() {
        move(toBoundary: .document, inDirection: .forward)
    }
}

private extension TextViewController {
    private func move(by granularity: TextGranularity, inDirection directon: TextDirection)  {
        if let currentlySelectedRange = selectedRange {
            navigationService.resetPreviousLineMovementOperation()
            selectedRange = selectionService.range(movingFrom: currentlySelectedRange, by: granularity, inDirection: directon)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection directon: TextDirection) {
        if let currentlySelectedRange = selectedRange {
            navigationService.resetPreviousLineMovementOperation()
            selectedRange = selectionService.range(movingFrom: currentlySelectedRange, toBoundary: boundary, inDirection: directon)
        }
    }
}
#endif
