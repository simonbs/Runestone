import Foundation

extension TextViewController {
    func moveLeft() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .character, offset: -1)
    }

    func moveRight() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .character, offset: 1)
    }

    func moveUp() {
        move(by: .line, offset: -1)
    }

    func moveDown() {
        move(by: .line, offset: 1)
    }

    func moveWordLeft() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .word, offset: -1)
    }

    func moveWordRight() {
        navigationService.resetPreviousLineMovementOperation()
        move(by: .word, offset: 1)
    }

    func moveToBeginningOfLine() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLine() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraph() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraph() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocument() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocument() {
        navigationService.resetPreviousLineMovementOperation()
        move(toBoundary: .document, inDirection: .forward)
    }

    func moveToLocation(closestTo point: CGPoint) {
        if let location = layoutManager.closestIndex(to: point) {
            navigationService.resetPreviousLineMovementOperation()
            selectedRange = NSRange(location: location, length: 0)
        }
    }
}

private extension TextViewController {
    private func move(by granularity: NavigationService.Granularity, offset: Int) {
        guard let sourceLocation = selectedRange?.location else {
            return
        }
        let destinationLocation = navigationService.location(movingFrom: sourceLocation, by: granularity, offset: offset)
        selectedRange = NSRange(location: destinationLocation, length: 0)
    }

    private func move(toBoundary boundary: NavigationService.Boundary, inDirection direction: NavigationService.Direction) {
        guard let sourceLocation = selectedRange?.location else {
            return
        }
        let destinationLocation = navigationService.location(movingFrom: sourceLocation, toBoundary: boundary, inDirection: direction)
        selectedRange = NSRange(location: destinationLocation, length: 0)
    }
}
