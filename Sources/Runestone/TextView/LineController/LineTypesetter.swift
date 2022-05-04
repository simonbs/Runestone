import CoreGraphics
import CoreText
import Foundation

private final class TypesetResult {
    let lineFragments: [LineFragment]
    let lineFragmentsMap: [LineFragmentID: Int]
    let maximumLineWidth: CGFloat

    init(lineFragments: [LineFragment], lineFragmentsMap: [LineFragmentID: Int], maximumLineWidth: CGFloat) {
        self.lineFragments = lineFragments
        self.lineFragmentsMap = lineFragmentsMap
        self.maximumLineWidth = maximumLineWidth
    }
}

final class LineTypesetter {
    private enum TypesetEndCondition {
        case yPosition(_ targetYPosition: CGFloat)
        case characterIndex(_ targetCharacterIndex: Int)

        func shouldKeepTypesetting(currentYPosition: CGFloat, currentCharacterIndex: Int) -> Bool {
            switch self {
            case .yPosition(let targetYPosition):
                return currentYPosition < targetYPosition
            case .characterIndex(let targetCharacterIndex):
                return currentCharacterIndex < targetCharacterIndex
            }
        }
    }

    var constrainingWidth: CGFloat = 0
    var lineFragmentHeightMultiplier: CGFloat = 1
    private(set) var lineFragments: [LineFragment] = []
    private(set) var maximumLineWidth: CGFloat = 0
    var bestGuessNumberOfLineFragments: Int {
        if startOffset >= stringLength {
            return lineFragments.count
        } else {
            let charactersPerLineFragment = Double(startOffset) / Double(lineFragments.count)
            let charactersRemaining = stringLength - startOffset
            let remainingNumberOfLineFragments = Int(ceil(Double(charactersRemaining) / charactersPerLineFragment))
            return lineFragments.count + remainingNumberOfLineFragments
        }
    }
    var isFinishedTypesetting: Bool {
        return startOffset >= stringLength
    }
    var typesetLength: Int {
        return startOffset
    }

    private let lineID: String
    private var stringLength = 0
    private var attributedString: NSAttributedString?
    private var typesetter: CTTypesetter?
    private var lineFragmentsMap: [LineFragmentID: Int] = [:]
    private var startOffset = 0
    private var nextYPosition: CGFloat = 0
    private var lineFragmentIndex = 0
    /// List of characters that we prefer wrapping a line after. These are less preferred than whitespace.
    /// If it's not possible to wrap a line after a whitespace or any of these characters, then we'll wrap after any character.
    private let preferredLineBreakCharacters = [",", ";"]

    init(lineID: String) {
        self.lineID = lineID
    }

    func reset() {
        lineFragments = []
        maximumLineWidth = 0
        stringLength = 0
        attributedString = nil
        typesetter = nil
        lineFragmentsMap = [:]
        startOffset = 0
        nextYPosition = 0
        lineFragmentIndex = 0
    }

    func prepareToTypeset(_ attributedString: NSAttributedString) {
        self.attributedString = attributedString
        stringLength = CFAttributedStringGetLength(attributedString)
        typesetter = CTTypesetterCreateWithAttributedString(attributedString)
    }

    @discardableResult
    func typesetLineFragments(in rect: CGRect) -> [LineFragment] {
        let lineFragments = typesetLineFragments(until: .yPosition(rect.maxY))
        if isFinishedTypesetting {
            attributedString = nil
            typesetter = nil
        }
        return lineFragments
    }

    @discardableResult
    func typesetLineFragments(toLocation location: Int, additionalLineFragmentCount: Int = 0) -> [LineFragment] {
        let lineFragments = typesetLineFragments(until: .characterIndex(location), additionalLineFragmentCount: additionalLineFragmentCount)
        if isFinishedTypesetting {
            attributedString = nil
            typesetter = nil
        }
        return lineFragments
    }

    func lineFragment(withID lineFragmentID: LineFragmentID) -> LineFragment? {
        if let index = lineFragmentsMap[lineFragmentID] {
            return lineFragments[index]
        } else {
            return nil
        }
    }
}

private extension LineTypesetter {
    private func updateState(from typesetResult: TypesetResult) {
        lineFragments.append(contentsOf: typesetResult.lineFragments)
        for (id, index) in typesetResult.lineFragmentsMap {
            lineFragmentsMap[id] = index
        }
        maximumLineWidth = max(maximumLineWidth, typesetResult.maximumLineWidth)
    }

    private func typesetLineFragments(until condition: TypesetEndCondition, additionalLineFragmentCount: Int = 0) -> [LineFragment] {
        guard let typesetter = typesetter else {
            return []
        }
        let typesetResult = typesetLineFragments(until: condition,
                                                 additionalLineFragmentCount: additionalLineFragmentCount,
                                                 using: typesetter,
                                                 stringLength: stringLength)
        updateState(from: typesetResult)
        return typesetResult.lineFragments
    }

    private func typesetLineFragments(until condition: TypesetEndCondition,
                                      additionalLineFragmentCount: Int = 0,
                                      using typesetter: CTTypesetter,
                                      stringLength: Int) -> TypesetResult {
        guard constrainingWidth > 0 else {
            return TypesetResult(lineFragments: [], lineFragmentsMap: [:], maximumLineWidth: 0)
        }
        var maximumLineWidth: CGFloat = 0
        var lineFragments: [LineFragment] = []
        var lineFragmentsMap: [LineFragmentID: Int] = [:]
        var remainingAdditionalLineFragmentCount = additionalLineFragmentCount
        let conditionAllowsKeepTypesetting = condition.shouldKeepTypesetting(currentYPosition: nextYPosition, currentCharacterIndex: startOffset)
        var shouldKeepTypesetting = conditionAllowsKeepTypesetting || remainingAdditionalLineFragmentCount > 0
        while startOffset < stringLength && shouldKeepTypesetting {
            let length = suggestNextLineBreak(using: typesetter)
            let range = CFRangeMake(startOffset, length)
            let lineFragment = makeLineFragment(for: range, in: typesetter, lineFragmentIndex: lineFragmentIndex, yPosition: nextYPosition)
            lineFragments.append(lineFragment)
            nextYPosition += lineFragment.scaledSize.height
            startOffset += length
            if lineFragment.scaledSize.width > maximumLineWidth {
                maximumLineWidth = lineFragment.scaledSize.width
            }
            lineFragmentsMap[lineFragment.id] = lineFragmentIndex
            lineFragmentIndex += 1
            if condition.shouldKeepTypesetting(currentYPosition: nextYPosition, currentCharacterIndex: startOffset) {
                shouldKeepTypesetting = true
            } else if remainingAdditionalLineFragmentCount > 0 {
                shouldKeepTypesetting = true
                remainingAdditionalLineFragmentCount -= 1
            } else {
                shouldKeepTypesetting = false
            }
        }
        return TypesetResult(lineFragments: lineFragments, lineFragmentsMap: lineFragmentsMap, maximumLineWidth: maximumLineWidth)
    }

    private func suggestNextLineBreak(using typesetter: CTTypesetter) -> Int {
        let length = CTTypesetterSuggestClusterBreak(typesetter, startOffset, Double(constrainingWidth))
        guard startOffset + length < stringLength else {
            // We've reached the end of the line.
            return length
        }
        let lastCharacterIndex = startOffset + length - 1
        let prefersLineBreakAfterCharacter = prefersInsertingLineBreakAfterCharacter(at: lastCharacterIndex)
        guard !prefersLineBreakAfterCharacter else {
            // We're breaking at a whitespace so we return the break suggested by CTTypesetter.
            return length
        }
        // CTTypesetter did not suggest breaking at a whitespace. We try to go back in the string to find a whitespace to break at.
        // If that fails we'll just use the break suggested by CTTypesetter. This workaround solves two issues:
        // 1. The results more closely matches the behavior of desktop editors like Nova. They tend to prefer breaking at whitespaces.
        // 2. It fixes an issue where breaking in the middle of the /> ligature would cause the slash not to be drawn. More info in this tweet:
        //    https://twitter.com/simonbs/status/1515961709671899137
        let maximumLookback = min(length, 100)
        if let lookbackLength = lookbackToFindFirstLineBreakableCharacter(startingAt: startOffset + length, maximumLookback: maximumLookback) {
            return length - lookbackLength
        } else {
            return length
        }
    }

    private func lookbackToFindFirstLineBreakableCharacter(startingAt startLocation: Int, maximumLookback: Int) -> Int? {
        var lookback = 0
        var foundWhitespace = false
        while lookback < maximumLookback && !foundWhitespace {
            if prefersInsertingLineBreakAfterCharacter(at: startLocation - lookback) {
                foundWhitespace = true
            } else {
                lookback += 1
            }
        }
        if foundWhitespace {
            // Subtract one to break at the whitespace we've found.
            return lookback - 1
        } else {
            return nil
        }
    }

    private func prefersInsertingLineBreakAfterCharacter(at location: Int) -> Bool {
        guard let attributedString = attributedString else {
            return false
        }
        let range = NSRange(location: location, length: 1)
        let attributedSubstring = attributedString.attributedSubstring(from: range)
        let string = attributedSubstring.string.trimmingCharacters(in: .whitespaces)
        if string.isEmpty {
            return true
        } else {
            return preferredLineBreakCharacters.contains(string)
        }
    }

    private func makeLineFragment(for range: CFRange, in typesetter: CTTypesetter, lineFragmentIndex: Int, yPosition: CGFloat) -> LineFragment {
        let line = CTTypesetterCreateLine(typesetter, range)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        let baseSize = CGSize(width: width, height: height)
        let scaledSize = CGSize(width: width, height: height * lineFragmentHeightMultiplier)
        let id = LineFragmentID(lineId: lineID, lineFragmentIndex: lineFragmentIndex)
        let nsRange = NSRange(location: range.location, length: range.length)
        return LineFragment(id: id,
                            index: lineFragmentIndex,
                            range: nsRange,
                            line: line,
                            descent: descent,
                            baseSize: baseSize,
                            scaledSize: scaledSize,
                            yPosition: yPosition)
    }
}
