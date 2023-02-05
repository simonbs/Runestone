import Foundation

extension TextViewController {
    func moveLeft() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(by: .character, inDirection: .backward)
    }

    func moveRight() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(by: .character, inDirection: .forward)
    }

    func moveUp() {
        resetPreviouslySelectedRange()
        move(by: .line, inDirection: .backward)
    }

    func moveDown() {
        resetPreviouslySelectedRange()
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeft() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(by: .word, inDirection: .backward)
    }

    func moveWordRight() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLine() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLine() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraph() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraph() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocument() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocument() {
        navigationService.resetPreviousLineMovementOperation()
        resetPreviouslySelectedRange()
        move(toBoundary: .document, inDirection: .forward)
    }

    func moveToLocation(closestTo point: CGPoint) {
        if let location = layoutManager.closestIndex(to: point) {
            navigationService.resetPreviousLineMovementOperation()
            resetPreviouslySelectedRange()
            selectedRange = NSRange(location: location, length: 0)
        }
    }
}

private extension TextViewController {
    private func move(by granularity: TextGranularity, inDirection direction: TextDirection) {
        guard let selectedRange = selectedRange?.nonNegativeLength else {
            return
        }
        let shouldMoveToSelectionEnd = selectedRange.length > 0 && granularity == .character
        if shouldMoveToSelectionEnd && direction == .forward {
            self.selectedRange = NSRange(location: selectedRange.upperBound, length: 0)
        } else if shouldMoveToSelectionEnd && direction == .backward {
            self.selectedRange = NSRange(location: selectedRange.lowerBound, length: 0)
        } else {
            let offset = direction == .forward ? 1 : -1
            let sourceLocation = direction == .forward ? selectedRange.upperBound : selectedRange.lowerBound
            let destinationLocation = navigationService.location(movingFrom: sourceLocation, by: offset, granularity: granularity)
            self.selectedRange = NSRange(location: destinationLocation, length: 0)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        guard let selectedRange = selectedRange?.nonNegativeLength else {
            return
        }
        let sourceLocation = direction == .forward ? selectedRange.upperBound : selectedRange.lowerBound
        let destinationLocation = navigationService.location(movingFrom: sourceLocation, toBoundary: boundary, inDirection: direction)
        self.selectedRange = NSRange(location: destinationLocation, length: 0)
    }

    private func resetPreviouslySelectedRange() {
        #if os(macOS)
        selectionService.resetPreviouslySelectedRange()
        #endif
    }
}
