import Foundation

struct WordNavigationLocationFactory {
    private let stringTokenizer: StringTokenizer

    init(stringTokenizer: StringTokenizer) {
        self.stringTokenizer = stringTokenizer
    }

    func location(movingFrom sourceLocation: Int, byWordCount offset: Int = 1, inDirection direction: TextDirection) -> Int {
        var destinationLocation: Int? = sourceLocation
        var remainingOffset = offset
        while let newSourceLocation = destinationLocation, remainingOffset > 0 {
            destinationLocation = stringTokenizer.location(from: newSourceLocation, toBoundary: .word, inDirection: direction)
            remainingOffset -= 1
        }
        return destinationLocation ?? sourceLocation
    }
}
