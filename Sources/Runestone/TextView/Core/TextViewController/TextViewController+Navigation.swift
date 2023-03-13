import Foundation

extension TextViewController {
    func moveLeft() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .character, inDirection: .backward)
    }

    func moveRight() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .character, inDirection: .forward)
    }

    func moveUp() {
        move(by: .line, inDirection: .backward)
    }

    func moveDown() {
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeft() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .word, inDirection: .backward)
    }

    func moveWordRight() {
        navigationService.resetPreviousLineNavigationOperation()
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLine() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLine() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraph() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraph() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocument() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocument() {
        navigationService.resetPreviousLineNavigationOperation()
        move(toBoundary: .document, inDirection: .forward)
    }

    func move(to location: Int) {
        navigationService.resetPreviousLineNavigationOperation()
        selectedRange.value = NSRange(location: location, length: 0)
    }
}

private extension TextViewController {
    private func move(by granularity: TextGranularity, inDirection direction: TextDirection) {
        let sourceSelectedRange = selectedRange.value.nonNegativeLength
        switch granularity {
        case .character:
            if sourceSelectedRange.length == 0 {
                let sourceLocation = sourceSelectedRange.bound(in: direction)
                let location = navigationService.location(movingFrom: sourceLocation, byCharacterCount: 1, inDirection: direction)
                selectedRange.value = NSRange(location: location, length: 0)
            } else {
                let location = sourceSelectedRange.bound(in: direction)
                selectedRange.value = NSRange(location: location, length: 0)
            }
        case .line:
            let location = navigationService.location(movingFrom: sourceSelectedRange.location, byLineCount: 1, inDirection: direction)
            selectedRange.value = NSRange(location: location, length: 0)
        case .word:
            let sourceLocation = sourceSelectedRange.bound(in: direction)
            let location = navigationService.location(movingFrom: sourceLocation, byWordCount: 1, inDirection: direction)
            selectedRange.value = NSRange(location: location, length: 0)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        let sourceSelectedRange = selectedRange.value.nonNegativeLength
        let sourceLocation = sourceSelectedRange.bound(in: direction)
        let location = navigationService.location(moving: sourceLocation, toBoundary: boundary, inDirection: direction)
        selectedRange.value = NSRange(location: location, length: 0)
    }
}

private extension NSRange {
    func bound(in direction: TextDirection) -> Int {
        switch direction {
        case .backward:
            return lowerBound
        case .forward:
            return upperBound
        }
    }
}
