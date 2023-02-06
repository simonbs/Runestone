#if os(macOS)
import Foundation

extension TextViewController {
    func moveLeftAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .character, inDirection: .backward)
    }

    func moveRightAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .character, inDirection: .forward)
    }

    func moveUpAndModifySelection() {
        move(by: .line, inDirection: .backward)
    }

    func moveDownAndModifySelection() {
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeftAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .word, inDirection: .backward)
    }

    func moveWordRightAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLineAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLineAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraphAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraphAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocumentAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocumentAndModifySelection() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .document, inDirection: .forward)
    }
}

private extension TextViewController {
    private func move(by granularity: TextGranularity, inDirection directon: TextDirection)  {
        if let currentlySelectedRange = selectedRange {
            selectedRange = selectionService.range(movingFrom: currentlySelectedRange, by: granularity, inDirection: directon)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection directon: TextDirection) {
        if let currentlySelectedRange = selectedRange {
            selectedRange = selectionService.range(movingFrom: currentlySelectedRange, toBoundary: boundary, inDirection: directon)
        }
    }
}
#endif
