import Foundation

final class StringTokenizer {
    enum Granularity {
        case line
        case paragraph
        case word
    }

    enum Direction {
        case forward
        case backward
    }

    var lineManager: LineManager
    var stringView: StringView

    private let lineControllerStorage: LineControllerStorage
    private var newlineCharacters: [Character] {
        [Symbol.Character.lineFeed, Symbol.Character.carriageReturn, Symbol.Character.carriageReturnLineFeed]
    }

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.stringView = stringView
        self.lineControllerStorage = lineControllerStorage
    }

    func isLocation(_ location: Int, atBoundary granularity: Granularity, inDirection direction: Direction) -> Bool {
        switch granularity {
        case .line:
            return isLocation(location, atLineBoundaryInDirection: direction)
        case .paragraph:
            return isLocation(location, atParagraphBoundaryInDirection: direction)
        case .word:
            return isLocation(location, atWordBoundaryInDirection: direction)
        }
    }

    func location(from location: Int, toBoundary granularity: Granularity, inDirection direction: Direction) -> Int? {
        switch granularity {
        case .line:
            return self.location(from: location, toLineBoundaryInDirection: direction)
        case .paragraph:
            return self.location(from: location, toParagraphBoundaryInDirection: direction)
        case .word:
            return self.location(from: location, toWordBoundaryInDirection: direction)
        }
    }
}

// MARK: - Lines
private extension StringTokenizer {
    private func isLocation(_ location: Int, atLineBoundaryInDirection direction: Direction) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        guard lineLocalLocation >= 0 && lineLocalLocation <= line.data.totalLength else {
            return false
        }
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return false
        }
        if direction == .forward {
            let isLastLineFragment = lineFragmentNode.index == lineController.numberOfLineFragments - 1
            if isLastLineFragment {
                return location == lineLocation + lineFragmentNode.location + lineFragmentNode.value - line.data.delimiterLength
            } else {
                return location == lineLocation + lineFragmentNode.location + lineFragmentNode.value
            }
        } else {
            return location == lineLocation + lineFragmentNode.location
        }
    }

    private func location(from location: Int, toLineBoundaryInDirection direction: Direction) -> Int? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return nil
        }
        if direction == .forward {
            if location == stringView.string.length {
                return location
            } else {
                let lineFragmentRangeUpperBound = lineFragmentNode.location + lineFragmentNode.value
                let preferredLocation = lineLocation + lineFragmentRangeUpperBound
                let lineEndLocation = lineLocation + line.data.totalLength
                if preferredLocation == lineEndLocation {
                    // Navigate to end of line but before the delimiter (\n etc.)
                    return preferredLocation - line.data.delimiterLength
                } else {
                    // Navigate to the end of the line but before the last character. This is a hack that avoids an issue where the caret is placed on the next line. The approach seems to be similar to what Textastic is doing.
                    let lastCharacterRange = stringView.string.customRangeOfComposedCharacterSequence(at: lineFragmentRangeUpperBound)
                    return lineLocation + lineFragmentRangeUpperBound - lastCharacterRange.length
                }
            }
        } else if location == 0 {
            return location
        } else {
            return lineLocation + lineFragmentNode.location
        }
    }
}

// MARK: - Paragraphs
private extension StringTokenizer {
    private func isLocation(_ location: Int, atParagraphBoundaryInDirection direction: Direction) -> Bool {
        // I can't seem to make Ctrl+A, Ctrl+E, Cmd+Left, and Cmd+Right work properly if this function returns anything but false.
        // I've tried various ways of determining the paragraph boundary but UIKit doesn't seem to be happy with anything I come up with ultimately leading to incorrect keyboard navigation. I haven't yet found any drawbacks to returning false in all cases.
        return false
    }

    private func location(from location: Int, toParagraphBoundaryInDirection direction: Direction) -> Int? {
        if direction == .forward {
            if location == stringView.string.length {
                return location
            } else {
                var currentIndex = location
                while currentIndex < stringView.string.length {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    if currentString.count == 1, let character = currentString.first, newlineCharacters.contains(character) {
                        break
                    }
                    currentIndex += 1
                }
                return currentIndex
            }
        } else {
            if location == 0 {
                return location
            } else {
                var currentIndex = location - 1
                while currentIndex > 0 {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    if currentString.count == 1, let character = currentString.first, newlineCharacters.contains(character) {
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
    private func isLocation(_ location: Int, atWordBoundaryInDirection direction: Direction) -> Bool {
        let alphanumerics: CharacterSet = .alphanumerics
        if direction == .forward {
            if location == 0 {
                return false
            } else if let previousCharacter = stringView.composedSubstring(at: location - 1) {
                if location == stringView.string.length {
                    return alphanumerics.containsAllCharacters(of: previousCharacter)
                } else if let character = stringView.composedSubstring(at: location) {
                    return alphanumerics.containsAllCharacters(of: previousCharacter) && !alphanumerics.containsAllCharacters(of: character)
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            if location == stringView.string.length {
                return false
            } else if let string = stringView.composedSubstring(at: location) {
                if location == 0 {
                    return alphanumerics.containsAllCharacters(of: string)
                } else if let previousCharacter = stringView.composedSubstring(at: location - 1) {
                    return alphanumerics.containsAllCharacters(of: string) && !alphanumerics.containsAllCharacters(of: previousCharacter)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func location(from location: Int, toWordBoundaryInDirection direction: Direction) -> Int? {
        let alphanumerics: CharacterSet = .alphanumerics
        if direction == .forward {
            if location == stringView.string.length {
                return location
            } else if let referenceString = stringView.composedSubstring(at: location) {
                let isReferenceStringAlphanumeric = alphanumerics.containsAllCharacters(of: referenceString)
                var currentIndex = location + 1
                while currentIndex < stringView.string.length {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    let isCurrentStringAlphanumeric = alphanumerics.containsAllCharacters(of: currentString)
                    if isReferenceStringAlphanumeric != isCurrentStringAlphanumeric {
                        break
                    }
                    currentIndex += 1
                }
                return currentIndex
            } else {
                return nil
            }
        } else {
            if location == 0 {
                return location
            } else if let referenceString = stringView.composedSubstring(at: location - 1) {
                let isReferenceStringAlphanumeric = alphanumerics.containsAllCharacters(of: referenceString)
                var currentIndex = location - 1
                while currentIndex > 0 {
                    guard let currentString = stringView.composedSubstring(at: currentIndex) else {
                        break
                    }
                    let isCurrentStringAlphanumeric = alphanumerics.containsAllCharacters(of: currentString)
                    if isReferenceStringAlphanumeric != isCurrentStringAlphanumeric {
                        currentIndex += 1
                        break
                    }
                    currentIndex -= 1
                }
                return currentIndex
            } else {
                return nil
            }
        }
    }
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

private extension StringView {
    func composedSubstring(at location: Int) -> String? {
        guard location >= 0 && location < string.length else {
            return nil
        }
        let range = string.customRangeOfComposedCharacterSequence(at: location)
        return substring(in: range)
    }
}

private extension CharacterSet {
    func containsAllCharacters(of string: String) -> Bool {
        var containsAllCharacters = true
        for char in string.unicodeScalars {
            if !contains(char) {
                containsAllCharacters = false
                break
            }
        }
        return containsAllCharacters
    }
}
