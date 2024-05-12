struct LineNavigationLocationProvider<StringViewType: StringView, LineManagerType: LineManaging> {
    let stringView: StringViewType
    let lineManager: LineManagerType

    func location(
        from sourceLocation: Int,
        inDirection direction: LineNavigationDirection,
        offset: Int
    ) -> Int {
        guard let line = lineManager.line(containingCharacterAt: sourceLocation) else {
            return sourceLocation
        }
        let lineLocalLocation = max(min(sourceLocation - line.location, line.totalLength), 0)
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        let lineFragmentLocalLocation = lineLocalLocation - lineFragment.range.location
        return location(
            from: lineFragmentLocalLocation,
            in: lineFragment,
            of: line,
            direction: direction,
            offset: offset
        )
    }
}

private extension LineNavigationLocationProvider {
    private func location<LineType: Line>(
        from location: Int,
        in lineFragment: LineType.LineFragmentType,
        of line: LineType,
        direction: LineNavigationDirection,
        offset: Int = 1
    ) -> Int {
        guard offset != 0 else {
            return self.location(from: location, in: lineFragment, of: line)
        }
        switch direction {
        case .up:
            return self.location(
                movingUpwardsFrom: location,
                in: lineFragment,
                of: line,
                offset: offset
            )
        case .down:
            return self.location(
                movingDownwardsFrom: location,
                in: lineFragment,
                of: line,
                offset: offset
            )
        }
    }

    private func location<LineType: Line>(
        from location: Int,
        in lineFragment: LineType.LineFragmentType,
        of line: LineType
    ) -> Int {
        let lineLocation = line.location
        let preferredLocation = lineLocation + lineFragment.range.location + location
        let maximumLocation = min(lineLocation + lineFragment.range.upperBound, lineLocation + line.length)
        let naiveLocation = min(preferredLocation, maximumLocation)
        guard naiveLocation < stringView.length else {
            return stringView.length
        }
        let composedRange = stringView.rangeOfComposedCharacterSequence(at: naiveLocation)
        return composedRange.location
    }

    private func location<LineType: Line>(
        movingUpwardsFrom location: Int,
        in lineFragment: LineType.LineFragmentType,
        of line: LineType,
        offset: Int
    ) -> Int {
        let takeLineCount = min(lineFragment.index, offset)
        let remainingOffset = offset - takeLineCount
        guard remainingOffset > 0 else {
            let nextLineFragment = line.lineFragment(atIndex: lineFragment.index - takeLineCount)
            return self.location(
                from: location,
                in: nextLineFragment,
                of: line,
                direction: .up,
                offset: 0
            )
        }
        let lineIndex = line.index
        guard lineIndex > 0 else {
            // We've reached the beginning of the document so we move to the first character.
            return 0
        }
        let previousLine = lineManager[lineIndex - 1]
        let nextLineFragment = previousLine.lineFragment(atIndex: previousLine.numberOfLineFragments - 1)
        return self.location(
            movingUpwardsFrom: location,
            in: nextLineFragment,
            of: previousLine,
            offset: remainingOffset - 1
        )
    }

    private func location<LineType: Line>(
        movingDownwardsFrom location: Int,
        in lineFragment: LineType.LineFragmentType,
        of line: LineType,
        offset: Int
    ) -> Int {
        let takeLineCount = min(line.numberOfLineFragments - lineFragment.index - 1, offset)
        let remainingOffset = offset - takeLineCount
        guard remainingOffset > 0 else {
            let nextLineFragment = line.lineFragment(atIndex: lineFragment.index + takeLineCount)
            return self.location(
                from: location,
                in: nextLineFragment,
                of: line,
                direction: .down,
                offset: 0
            )
        }
        let lineIndex = line.index
        guard lineIndex < lineManager.lineCount - 1 else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.totalLength
        }
        let nextLine = lineManager[lineIndex + 1]
        let nextLineFragment = nextLine.lineFragment(atIndex: 0)
        return self.location(
            movingDownwardsFrom: location,
            in: nextLineFragment,
            of: nextLine,
            offset: remainingOffset - 1
        )
    }
}
