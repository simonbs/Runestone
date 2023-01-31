import Foundation

final class LineNavigationService {
    var lineManager: LineManager
    var lineControllerStorage: LineControllerStorage

    init(lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
    }

    func location(movingFrom sourceLocation: Int, byOffset offset: Int) -> Int {
        guard let line = lineManager.line(containingCharacterAt: sourceLocation) else {
            return sourceLocation
        }
        guard let lineController = lineControllerStorage[line.id] else {
            return sourceLocation
        }
        let lineLocalLocation = max(min(sourceLocation - line.location, line.data.totalLength), 0)
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return sourceLocation
        }
        let lineFragmentLocalLocation = lineLocalLocation - lineFragmentNode.location
        return locationForMoving(
            lineOffset: offset,
            fromLocation: lineFragmentLocalLocation,
            inLineFragmentAt: lineFragmentNode.index,
            of: line
        )
    }
}

private extension LineNavigationService {
    private func locationForMoving(
        lineOffset: Int,
        fromLocation location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: DocumentLineNode
    ) -> Int {
        if lineOffset < 0 {
            return locationForMovingUpwards(
                lineOffset: abs(lineOffset),
                fromLocation: location,
                inLineFragmentAt: lineFragmentIndex, of: line
            )
        } else if lineOffset > 0 {
            return locationForMovingDownwards(
                lineOffset: lineOffset,
                fromLocation: location,
                inLineFragmentAt: lineFragmentIndex,
                of: line
            )
        } else {
            // lineOffset is 0 so we should not change the line.
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            let destinationLineFragmentNode = lineController.lineFragmentNode(atIndex: lineFragmentIndex)
            let lineLocation = line.location
            let preferredLocation = lineLocation + destinationLineFragmentNode.location + location
            let lineFragmentMaximumLocation = lineLocation + destinationLineFragmentNode.location + destinationLineFragmentNode.value
            let lineMaximumLocation = lineLocation + line.data.length
            let maximumLocation = min(lineFragmentMaximumLocation, lineMaximumLocation)
            return min(preferredLocation, maximumLocation)
        }
    }

    private func locationForMovingUpwards(
        lineOffset: Int,
        fromLocation location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: DocumentLineNode
    ) -> Int {
        let takeLineCount = min(lineFragmentIndex, lineOffset)
        let remainingLineOffset = lineOffset - takeLineCount
        guard remainingLineOffset > 0 else {
            return locationForMoving(lineOffset: 0, fromLocation: location, inLineFragmentAt: lineFragmentIndex - takeLineCount, of: line)
        }
        let lineIndex = line.index
        guard lineIndex > 0 else {
            // We've reached the beginning of the document so we move to the first character.
            return 0
        }
        let previousLine = lineManager.line(atRow: lineIndex - 1)
        let numberOfLineFragments = numberOfLineFragments(in: previousLine)
        let newLineFragmentIndex = numberOfLineFragments - 1
        return locationForMovingUpwards(
            lineOffset: remainingLineOffset - 1,
            fromLocation: location,
            inLineFragmentAt: newLineFragmentIndex,
            of: previousLine
        )
    }

    private func locationForMovingDownwards(
        lineOffset: Int,
        fromLocation location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: DocumentLineNode
    ) -> Int {
        let numberOfLineFragments = numberOfLineFragments(in: line)
        let takeLineCount = min(numberOfLineFragments - lineFragmentIndex - 1, lineOffset)
        let remainingLineOffset = lineOffset - takeLineCount
        guard remainingLineOffset > 0 else {
            return locationForMoving(lineOffset: 0, fromLocation: location, inLineFragmentAt: lineFragmentIndex + takeLineCount, of: line)
        }
        let lineIndex = line.index
        guard lineIndex < lineManager.lineCount - 1 else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.data.totalLength
        }
        let nextLine = lineManager.line(atRow: lineIndex + 1)
        return locationForMovingDownwards(
            lineOffset: remainingLineOffset - 1,
            fromLocation: location,
            inLineFragmentAt: 0,
            of: nextLine)
    }

    private func numberOfLineFragments(in line: DocumentLineNode) -> Int {
        lineControllerStorage.getOrCreateLineController(for: line).numberOfLineFragments
    }
}
