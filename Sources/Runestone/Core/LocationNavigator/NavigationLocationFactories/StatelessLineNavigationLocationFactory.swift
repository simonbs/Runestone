import Combine

struct StatelessLineNavigationLocationFactory: LineNavigationLocationFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    let lineControllerStorage: LineControllerStorage

    func location(movingFrom sourceLocation: Int, byLineCount offset: Int = 1, inDirection direction: TextDirection) -> Int {
        guard let line = lineManager.value.line(containingCharacterAt: sourceLocation) else {
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
        return location(
            movingFrom: lineFragmentLocalLocation,
            inLineFragmentAt: lineFragmentNode.index,
            of: line,
            offset: offset,
            inDirection: direction
        )
    }

    func location(
        movingFrom location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: LineNode,
        offset: Int = 1,
        inDirection direction: TextDirection
    ) -> Int {
        if offset == 0 {
            return self.location(movingFrom: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else {
            switch direction {
            case .forward:
                return self.location(movingForwardsFrom: location, inLineFragmentAt: lineFragmentIndex, of: line, offset: offset)
            case .backward:
                return self.location(movingBackwardsFrom: location, inLineFragmentAt: lineFragmentIndex, of: line, offset: offset)
            }
        }
    }
}

private extension StatelessLineNavigationLocationFactory {
    private func location(movingFrom location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: LineNode) -> Int {
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let destinationLineFragmentNode = lineController.lineFragmentNode(atIndex: lineFragmentIndex)
        let lineLocation = line.location
        let preferredLocation = lineLocation + destinationLineFragmentNode.location + location
        let lineFragmentMaximumLocation = lineLocation + destinationLineFragmentNode.location + destinationLineFragmentNode.value
        let lineMaximumLocation = lineLocation + line.data.length
        let maximumLocation = min(lineFragmentMaximumLocation, lineMaximumLocation)
        let naiveLocation = min(preferredLocation, maximumLocation)
        let range = stringView.value.string.customRangeOfComposedCharacterSequence(at: naiveLocation)
        return range.location
    }

    private func location(movingBackwardsFrom location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: LineNode, offset: Int) -> Int {
        let takeLineCount = min(lineFragmentIndex, offset)
        let remainingOffset = offset - takeLineCount
        guard remainingOffset > 0 else {
            return self.location(
                movingFrom: location,
                inLineFragmentAt: lineFragmentIndex - takeLineCount,
                of: line,
                offset: 0,
                inDirection: .backward
            )
        }
        let lineIndex = line.index
        guard lineIndex > 0 else {
            // We've reached the beginning of the document so we move to the first character.
            return 0
        }
        let previousLine = lineManager.value.line(atRow: lineIndex - 1)
        let numberOfLineFragments = numberOfLineFragments(in: previousLine)
        let newLineFragmentIndex = numberOfLineFragments - 1
        return self.location(movingBackwardsFrom: location, inLineFragmentAt: newLineFragmentIndex, of: previousLine, offset: remainingOffset - 1)
    }

    private func location(movingForwardsFrom location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: LineNode, offset: Int) -> Int {
        let numberOfLineFragments = numberOfLineFragments(in: line)
        let takeLineCount = min(numberOfLineFragments - lineFragmentIndex - 1, offset)
        let remainingOffset = offset - takeLineCount
        guard remainingOffset > 0 else {
            return self.location(
                movingFrom: location,
                inLineFragmentAt: lineFragmentIndex + takeLineCount,
                of: line,
                offset: 0,
                inDirection: .forward
            )
        }
        let lineIndex = line.index
        guard lineIndex < lineManager.value.lineCount - 1 else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.data.totalLength
        }
        let nextLine = lineManager.value.line(atRow: lineIndex + 1)
        return self.location(movingForwardsFrom: location, inLineFragmentAt: 0, of: nextLine, offset: remainingOffset - 1)
    }

    private func numberOfLineFragments(in line: LineNode) -> Int {
        lineControllerStorage.getOrCreateLineController(for: line).numberOfLineFragments
    }
}
