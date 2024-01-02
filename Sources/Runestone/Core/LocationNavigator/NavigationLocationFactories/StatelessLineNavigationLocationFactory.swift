import Combine

struct StatelessLineNavigationLocationFactory<
    LineManagerType: LineManaging
>: LineNavigationLocationFactory {
    let stringView: StringView
    let lineManager: LineManagerType

    func location(
        movingFrom sourceLocation: Int,
        byLineCount offset: Int = 1,
        inDirection direction: TextDirection
    ) -> Int {
        guard let line = lineManager.line(containingCharacterAt: sourceLocation) else {
            return sourceLocation
        }
        let lineLocalLocation = max(min(sourceLocation - line.location, line.totalLength), 0)
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        let lineFragmentLocalLocation = lineLocalLocation - lineFragment.range.location
        return location(
            movingFrom: lineFragmentLocalLocation,
            inLineFragmentAt: lineFragment.index,
            of: line,
            offset: offset,
            inDirection: direction
        )
    }

    func location(
        movingFrom location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: some Line,
        offset: Int = 1,
        inDirection direction: TextDirection
    ) -> Int {
        if offset == 0 {
            return self.location(movingFrom: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else {
            switch direction {
            case .forward:
                return self.location(
                    movingForwardsFrom: location, 
                    inLineFragmentAt: lineFragmentIndex,
                    of: line,
                    offset: offset
                )
            case .backward:
                return self.location(
                    movingBackwardsFrom: location,
                    inLineFragmentAt: lineFragmentIndex,
                    of: line,
                    offset: offset
                )
            }
        }
    }
}

private extension StatelessLineNavigationLocationFactory {
    private func location(
        movingFrom location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: some Line
    ) -> Int {
        let destinationLineFragment = line.lineFragment(atIndex: lineFragmentIndex)
        let lineLocation = line.location
        let preferredLocation = lineLocation + destinationLineFragment.range.location + location
        let lineFragmentMaximumLocation = lineLocation + destinationLineFragment.range.upperBound
        let lineMaximumLocation = lineLocation + line.length
        let maximumLocation = min(lineFragmentMaximumLocation, lineMaximumLocation)
        let naiveLocation = min(preferredLocation, maximumLocation)
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: naiveLocation)
        return range.location
    }

    private func location(
        movingBackwardsFrom location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: some Line,
        offset: Int
    ) -> Int {
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
        let previousLine = lineManager[lineIndex - 1]
        let newLineFragmentIndex = previousLine.numberOfLineFragments - 1
        return self.location(
            movingBackwardsFrom: location,
            inLineFragmentAt: newLineFragmentIndex,
            of: previousLine,
            offset: remainingOffset - 1
        )
    }

    private func location(
        movingForwardsFrom location: Int,
        inLineFragmentAt lineFragmentIndex: Int,
        of line: some Line,
        offset: Int
    ) -> Int {
        let takeLineCount = min(line.numberOfLineFragments - lineFragmentIndex - 1, offset)
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
        guard lineIndex < lineManager.lineCount - 1 else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.totalLength
        }
        let nextLine = lineManager[lineIndex + 1]
        return self.location(
            movingForwardsFrom: location, 
            inLineFragmentAt: 0, 
            of: nextLine,
            offset: remainingOffset - 1
        )
    }
}
