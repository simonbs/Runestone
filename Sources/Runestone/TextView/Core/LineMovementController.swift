import UIKit

final class LineMovementController {
    var lineManager: LineManager
    var stringView: StringView
    let lineControllerStorage: LineControllerStorage

    init(lineManager: LineManager, stringView: StringView, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.stringView = stringView
        self.lineControllerStorage = lineControllerStorage
    }

    func location(from location: Int, in direction: UITextLayoutDirection, offset: Int) -> Int? {
        let newLocation: Int?
        switch direction {
        case .left:
            newLocation = HorizontalTextMovement.location(from: location, offset: offset * -1,
                                                          stringView: stringView, lineManager: lineManager)
        case .right:
            newLocation = HorizontalTextMovement.location(from: location, offset: offset,
                                                          stringView: stringView, lineManager: lineManager)
        case .up:
            newLocation = locationForMoving(lineOffset: offset * -1, fromLineContainingCharacterAt: location)
        case .down:
            newLocation = locationForMoving(lineOffset: offset, fromLineContainingCharacterAt: location)
        @unknown default:
            newLocation = nil
        }
        if let newLocation = newLocation, newLocation >= 0 && newLocation <= stringView.string.length {
            return newLocation
        } else {
            return nil
        }
    }
}

private extension LineMovementController {
    private func locationForMoving(lineOffset: Int, fromLineContainingCharacterAt location: Int) -> Int {
        guard lineOffset != 0 else {
            return location
        }
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return location
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocalLocation = max(min(location - line.location, line.data.totalLength), 0)
        // Keyboard navigation can query a position beyond the fragments prepared by viewport layout.
        lineController.prepareToDisplayString(toLocation: lineLocalLocation, syntaxHighlightAsynchronously: true)
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return location
        }
        let lineFragmentLocalLocation = lineLocalLocation - lineFragmentNode.location
        return locationForMoving(lineOffset: lineOffset, fromLocation: lineFragmentLocalLocation, inLineFragmentAt: lineFragmentNode.index, of: line)
    }

    private func locationForMoving(lineOffset: Int,
                                   fromLocation location: Int,
                                   inLineFragmentAt lineFragmentIndex: Int,
                                   of line: DocumentLineNode) -> Int {
        if lineOffset < 0 {
            return locationForMovingUpwards(lineOffset: abs(lineOffset), fromLocation: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else if lineOffset > 0 {
            return locationForMovingDownwards(lineOffset: lineOffset, fromLocation: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else {
            // lineOffset is 0 so we shouldn't change the line
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

    private func locationForMovingUpwards(lineOffset: Int,
                                          fromLocation location: Int,
                                          inLineFragmentAt lineFragmentIndex: Int,
                                          of line: DocumentLineNode) -> Int {
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
        guard let previousLine = lineManager.previousVisibleLine(before: line) else {
            return 0
        }
        let previousLineController = lineControllerStorage.getOrCreateLineController(for: previousLine)
        // Moving up enters the previous logical line at its final wrapped fragment.
        previousLineController.prepareToDisplayString(toLocation: previousLine.data.totalLength, syntaxHighlightAsynchronously: true)
        let newLineFragmentIndex = previousLineController.numberOfLineFragments - 1
        return locationForMovingUpwards(lineOffset: remainingLineOffset - 1,
                                        fromLocation: location,
                                        inLineFragmentAt: newLineFragmentIndex,
                                        of: previousLine)
    }

    private func locationForMovingDownwards(lineOffset: Int,
                                            fromLocation location: Int,
                                            inLineFragmentAt lineFragmentIndex: Int,
                                            of line: DocumentLineNode) -> Int {
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        // Only prepare the requested destination, keeping short movements in very long lines bounded.
        lineController.prepareToDisplayString(toLineFragmentIndex: lineFragmentIndex + lineOffset, syntaxHighlightAsynchronously: true)
        let numberOfLineFragments = lineController.numberOfLineFragments
        let takeLineCount = min(numberOfLineFragments - lineFragmentIndex - 1, lineOffset)
        let remainingLineOffset = lineOffset - takeLineCount
        guard remainingLineOffset > 0 else {
            return locationForMoving(lineOffset: 0, fromLocation: location, inLineFragmentAt: lineFragmentIndex + takeLineCount, of: line)
        }
        let lineIndex = line.index
        guard lineIndex < lineManager.lastVisibleLine.index else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.data.length
        }
        guard let nextLine = lineManager.nextVisibleLine(after: line) else {
            return line.location + line.data.length
        }
        return locationForMovingDownwards(lineOffset: remainingLineOffset - 1, fromLocation: location, inLineFragmentAt: 0, of: nextLine)
    }

}
