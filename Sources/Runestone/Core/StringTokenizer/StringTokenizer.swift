import Combine
import Foundation

struct StringTokenizer<StringViewType: StringView, LineManagerType: LineManaging>: StringTokenizing {
    let stringView: StringViewType
    let lineManager: LineManagerType

    private var newlineCharacters: [Character] {
        [
            Symbol.Character.lineFeed,
            Symbol.Character.carriageReturn,
            Symbol.Character.carriageReturnLineFeed
        ]
    }

    func isLocation(
        _ location: Int,
        atBoundary boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> Bool {
        switch boundary {
        case .word:
            return isLocation(location, atWordBoundaryInDirection: direction)
        case .line:
            return isLocation(location, atLineBoundaryInDirection: direction)
        case .paragraph:
            return isLocation(location, atParagraphBoundaryInDirection: direction)
        case .document:
            return isLocation(location, atDocumentBoundaryInDirection: direction)
        }
    }

    func location(
        from location: Int,
        toBoundary boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> Int? {
        switch boundary {
        case .word:
            return self.location(from: location, toWordBoundaryInDirection: direction)
        case .line:
            return self.location(from: location, toLineBoundaryInDirection: direction)
        case .paragraph:
            return self.location(from: location, toParagraphBoundaryInDirection: direction)
        case .document:
            return self.location(toDocumentBoundaryInDirection: direction)
        }
    }
}

// MARK: - Lines
private extension StringTokenizer {
    private func isLocation(_ location: Int, atLineBoundaryInDirection direction: TextDirection) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        guard lineLocalLocation >= 0 && lineLocalLocation <= line.totalLength else {
            return false
        }
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        switch direction {
        case .forward:
            let isLastLineFragment = lineFragment.index == line.numberOfLineFragments - 1
            if isLastLineFragment {
                return location == lineLocation + lineFragment.range.upperBound - line.delimiterLength
            } else {
                return location == lineLocation + lineFragment.range.upperBound
            }
        case .backward:
            return location == lineLocation + lineFragment.range.location
        }
    }

    private func location(from location: Int, toLineBoundaryInDirection direction: TextDirection) -> Int? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        if direction == .forward {
            if location == stringView.length {
                return location
            } else {
                let lineFragmentRangeUpperBound = lineFragment.range.upperBound
                let preferredLocation = lineLocation + lineFragmentRangeUpperBound
                let lineEndLocation = lineLocation + line.totalLength
                if preferredLocation == lineEndLocation {
                    // Navigate to end of line but before the delimiter (\n etc.)
                    return preferredLocation - line.delimiterLength
                } else {
                    // Navigate to the end of the line but before the last character. This is a hack that avoids an issue where the caret is placed on the next line. The approach seems to be similar to what Textastic is doing.
                    let lastCharacterRange = stringView.string.customRangeOfComposedCharacterSequence(at: lineFragmentRangeUpperBound)
                    return lineLocation + lineFragmentRangeUpperBound - lastCharacterRange.length
                }
            }
        } else if location == 0 {
            return location
        } else {
            return lineLocation + lineFragment.range.location
        }
    }
}

// MARK: - Paragraphs
private extension StringTokenizer {
    private func isLocation(_ location: Int, atParagraphBoundaryInDirection direction: TextDirection) -> Bool {
        // I can't seem to make Ctrl+A, Ctrl+E, Cmd+Left, and Cmd+Right work properly if this
        // function returns anything but false. I've tried various ways of determining the
        // paragraph boundary but UIKit doesn't seem to be happy with anything I come up with
        // ultimately leading to incorrect keyboard navigation. I haven't yet found any drawbacks
        // to returning false in all cases.
        return false
    }

    private func location(from location: Int, toParagraphBoundaryInDirection direction: TextDirection) -> Int? {
        switch direction {
        case .forward:
            if location == stringView.length {
                return location
            } else {
                var currentIndex = location
                while currentIndex < stringView.length {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    if currentString.count == 1,
                       let character = currentString.first,
                       newlineCharacters.contains(character)
                    {
                        break
                    }
                    currentIndex += 1
                }
                return currentIndex
            }
        case .backward:
            if location == 0 {
                return location
            } else {
                var currentIndex = location - 1
                while currentIndex > 0 {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    if currentString.count == 1,
                       let character = currentString.first,
                       newlineCharacters.contains(character)
                    {
                        currentIndex += 1
                        break
                    }
                    currentIndex -= 1
                }
                return currentIndex
            }
        }
    }
}

// MARK: - Words
private extension StringTokenizer {
    private func isLocation(_ location: Int, atWordBoundaryInDirection direction: TextDirection) -> Bool {
        let alphanumerics: CharacterSet = .alphanumerics
        switch direction {
        case .forward:
            if location == 0 {
                return false
            } else if let previousCharacter = stringView.composedSubstring(at: location - 1) {
                if location == stringView.length {
                    return alphanumerics.containsAllCharacters(of: previousCharacter)
                } else if let character = stringView.composedSubstring(at: location) {
                    return alphanumerics.containsAllCharacters(of: previousCharacter) 
                    && !alphanumerics.containsAllCharacters(of: character)
                } else {
                    return false
                }
            } else {
                return false
            }
        case .backward:
            if location == stringView.length {
                return false
            } else if let string = stringView.composedSubstring(at: location) {
                if location == 0 {
                    return alphanumerics.containsAllCharacters(of: string)
                } else if let previousCharacter = stringView.composedSubstring(at: location - 1) {
                    return alphanumerics.containsAllCharacters(of: string) 
                    && !alphanumerics.containsAllCharacters(of: previousCharacter)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    private func location(from location: Int, toWordBoundaryInDirection direction: TextDirection) -> Int? {
        func advanceIndex(_ index: Int) -> Int {
            let preferredIndex: Int
            switch direction {
            case .forward:
                preferredIndex = index + 1
            case .backward:
                preferredIndex = index - 1
            }
            return min(max(preferredIndex, 0), stringView.length)
        }
        func hasReachedEnd(at index: Int) -> Bool {
            switch direction {
            case .forward:
                return index == stringView.length
            case .backward:
                return index == 0
            }
        }
        var index = location
        if isLocation(index, atBoundary: .word, inDirection: direction) {
            index = advanceIndex(index)
        }
        while !isLocation(index, atBoundary: .word, inDirection: direction) && !hasReachedEnd(at: index) {
            index = advanceIndex(index)
        }
        return index
    }
}

// MARK: - Document
private extension StringTokenizer {
    private func isLocation(_ location: Int, atDocumentBoundaryInDirection direction: TextDirection) -> Bool {
        switch direction {
        case .backward:
            return location == 0
        case .forward:
            return location == stringView.length
        }
    }

    private func location(toDocumentBoundaryInDirection direction: TextDirection) -> Int {
        switch direction {
        case .backward:
            return 0
        case .forward:
            return stringView.length
        }
    }
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains(_:))
    }
}

private extension StringView {
    func composedSubstring(at location: Int) -> String? {
        guard location >= 0 && location < length else {
            return nil
        }
        let range = string.customRangeOfComposedCharacterSequence(at: location)
        return substring(in: range)
    }
}
