//
//  BracketMatcher.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

private final class BracketMatchingCountResult {
    private var map: [String: Int] = [:]

    var containsOpenBracket: Bool {
        return map.contains { _, count in
            return count > 0
        }
    }

    func increment(_ characterPair: EditorCharacterPair) {
        let key = key(for: characterPair)
        map[key] = (map[key] ?? 0) + 1
    }

    func decrement(_ characterPair: EditorCharacterPair) {
        let key = key(for: characterPair)
        map[key] = (map[key] ?? 0) - 1
    }

    func containsBracket(matchedBy otherCountResult: BracketMatchingCountResult) -> Bool {
        // A bracket is one set is matched by a bracket in another set if adding the two counts equals zero.
        // Consider set a A where "{}" = 1 and set B where "{}" = -1. "{}" is the key in the map.
        // A has an opening bracket that's unmatched and set B has a closing bracket that's unmatched.
        return map.contains { key, aCount in
            if let bCount = otherCountResult.map[key] {
                return aCount + bCount == 0
            } else {
                return false
            }
        }
    }
}

private extension BracketMatchingCountResult {
    private func key(for characterPair: EditorCharacterPair) -> String {
        return characterPair.leading + characterPair.trailing
    }
}

extension BracketMatchingCountResult: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[BracketMatchingCountResult map=\(map)]"
    }
}

final class BracketMatcher {
    private enum ScanDirection {
        case left
        case right
    }

    private let characterPairs: [EditorCharacterPair]
    private let stringView: StringView

    init(characterPairs: [EditorCharacterPair], stringView: StringView) {
        self.characterPairs = characterPairs.filter(\.insertAdditionalNewLine)
        self.stringView = stringView
    }

    func hasMatchingBrackets(at location: Int, in lineRange: ClosedRange<Int>) -> Bool {
        return hasMatchingBrackets(surrounding: location ... location, in: lineRange)
    }

    func hasMatchingBrackets(surrounding range: ClosedRange<Int>, in lineRange: ClosedRange<Int>) -> Bool {
        // The max look around defines a maximum amount of characters to scan in each direction.
        // Increasing the number can cause worse performance but better results.
        // In most cases it shouldn't need to be large though.
        let maxLookAround = 200
        let lineStartLocation = lineRange.lowerBound
        let lowerLocationBound = max(range.lowerBound - maxLookAround, lineStartLocation)
        let upperLocationBound = min(range.upperBound + maxLookAround, lineRange.upperBound)
        let limitingBounds = lowerLocationBound ... upperLocationBound
        let leadingCountResult = countLeadingPairs(startingAt: range.lowerBound, limitedTo: limitingBounds)
        if leadingCountResult.containsOpenBracket {
            let trailingCountResult = countTrailingPairs(startingAt: range.upperBound, limitedTo: limitingBounds)
            return leadingCountResult.containsBracket(matchedBy: trailingCountResult)
        } else {
            return false
        }
    }
}

private extension BracketMatcher {
    private func countLeadingPairs(startingAt location: Int, limitedTo limitingBounds: ClosedRange<Int>) -> BracketMatchingCountResult {
        let result = BracketMatchingCountResult()
        count(startingAt: location, limitedTo: limitingBounds, direction: .left, result: result)
        return result
    }

    private func countTrailingPairs(startingAt location: Int, limitedTo limitingBounds: ClosedRange<Int>) -> BracketMatchingCountResult {
        let result = BracketMatchingCountResult()
        count(startingAt: location, limitedTo: limitingBounds, direction: .right, result: result)
        return result
    }

    private func count(startingAt location: Int, limitedTo limitingBounds: ClosedRange<Int>, direction: ScanDirection, result: BracketMatchingCountResult) {
        guard limitingBounds.contains(location)else {
            return
        }
        var stringMap: [NSRange: String] = [:]
        func getString(in range: NSRange) -> String {
            if let existingString = stringMap[range] {
                return existingString
            } else {
                let string = stringView.substring(in: range)
                stringMap[range] = string
                return string
            }
        }
        for characterPair in characterPairs {
            let leadingLength = characterPair.leading.count
            let trailingLength = characterPair.trailing.count
            let startLeadingLocation: Int
            let startTrailingLocation: Int
            switch direction {
            case .left:
                startLeadingLocation = location - leadingLength
                startTrailingLocation = location - trailingLength
            case .right:
                startLeadingLocation = location
                startTrailingLocation = location
            }
            if limitingBounds.contains(startLeadingLocation) && limitingBounds.contains(startLeadingLocation + leadingLength) {
                let range = NSRange(location: startLeadingLocation, length: leadingLength)
                let string = getString(in: range)
                if string == characterPair.leading {
                    result.increment(characterPair)
                }
            }
            if limitingBounds.contains(startTrailingLocation) && limitingBounds.contains(startTrailingLocation + trailingLength) {
                let range = NSRange(location: startTrailingLocation, length: trailingLength)
                let string = getString(in: range)
                if string == characterPair.trailing {
                    result.decrement(characterPair)
                }
            }
        }
        switch direction {
        case .left:
            count(startingAt: location - 1, limitedTo: limitingBounds, direction: direction, result: result)
        case .right:
            count(startingAt: location + 1, limitedTo: limitingBounds, direction: direction, result: result)
        }
    }
}
