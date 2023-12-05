import Combine
import Foundation

struct LocationNavigator: LocationNavigating {
    typealias State = SelectedRangeWritable

    let state: State
    let stringTokenizer: StringTokenizing
    let characterNavigationLocationService: CharacterNavigationLocationFactory
    let wordNavigationLocationService: WordNavigationLocationFactory
    let lineNavigationLocationFactory: LineNavigationLocationFactory

    func moveLeft() {
        lineNavigationLocationFactory.reset()
        move(by: .character, inDirection: .backward)
    }

    func moveRight() {
        lineNavigationLocationFactory.reset()
        move(by: .character, inDirection: .forward)
    }

    func moveUp() {
        move(by: .line, inDirection: .backward)
    }

    func moveDown() {
        move(by: .line, inDirection: .forward)
    }

    func moveWordLeft() {
        lineNavigationLocationFactory.reset()
        move(by: .word, inDirection: .backward)
    }

    func moveWordRight() {
        lineNavigationLocationFactory.reset()
        move(by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLine() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLine() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraph() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraph() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocument() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocument() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .document, inDirection: .forward)
    }

    func move(to location: Int) {
        lineNavigationLocationFactory.reset()
        state.selectedRange = NSRange(location: location, length: 0)
    }
}

private extension LocationNavigator {
    private func move(by granularity: TextGranularity, inDirection direction: TextDirection) {
        let sourceSelectedRange = state.selectedRange.nonNegativeLength
        switch granularity {
        case .character:
            if sourceSelectedRange.length == 0 {
                let sourceLocation = sourceSelectedRange.bound(in: direction)
                let location = location(
                    movingFrom: sourceLocation,
                    byCharacterCount: 1,
                    inDirection: direction
                )
                state.selectedRange = NSRange(location: location, length: 0)
            } else {
                let location = sourceSelectedRange.bound(in: direction)
                state.selectedRange = NSRange(location: location, length: 0)
            }
        case .line:
            let location = location(
                movingFrom: sourceSelectedRange.location,
                byLineCount: 1,
                inDirection: direction
            )
            state.selectedRange = NSRange(location: location, length: 0)
        case .word:
            let sourceLocation = sourceSelectedRange.bound(in: direction)
            let location = location(
                movingFrom: sourceLocation,
                byWordCount: 1,
                inDirection: direction
            )
            state.selectedRange = NSRange(location: location, length: 0)
        }
    }

    private func move(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        let sourceSelectedRange = state.selectedRange.nonNegativeLength
        let sourceLocation = sourceSelectedRange.bound(in: direction)
        let location = location(moving: sourceLocation, toBoundary: boundary, inDirection: direction)
        state.selectedRange = NSRange(location: location, length: 0)
    }

    private func location(
        movingFrom location: Int,
        byCharacterCount offset: Int,
        inDirection direction: TextDirection
    ) -> Int {
        characterNavigationLocationService.location(
            movingFrom: location,
            byCharacterCount: offset,
            inDirection: direction
        )
    }

    private func location(
        movingFrom location: Int,
        byLineCount offset: Int,
        inDirection direction: TextDirection
    ) -> Int {
        lineNavigationLocationFactory.location(
            movingFrom: location,
            byLineCount: offset,
            inDirection: direction
        )
    }

    private func location(
        movingFrom sourceLocation: Int,
        byWordCount offset: Int,
        inDirection direction: TextDirection
    ) -> Int {
        wordNavigationLocationService.location(
            movingFrom: sourceLocation,
            byWordCount: offset,
            inDirection: direction
        )
    }

    private func location(
        moving sourceLocation: Int,
        toBoundary boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> Int {
        stringTokenizer.location(
            from: sourceLocation, 
            toBoundary: boundary,
            inDirection: direction
        ) ?? sourceLocation
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
