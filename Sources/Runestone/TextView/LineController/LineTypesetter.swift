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

    var lineBreakMode: LineBreakMode = .byWordWrapping
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
        startOffset >= stringLength
    }
    var typesetLength: Int {
        startOffset
    }

    private let lineID: String
    private var stringLength = 0
    private var attributedString: NSAttributedString?
    private var typesetter: CTTypesetter?
    private var lineFragmentsMap: [LineFragmentID: Int] = [:]
    private var startOffset = 0
    private var nextYPosition: CGFloat = 0
    private var lineFragmentIndex = 0

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
        let typesetResult = typesetLineFragments(
            until: condition,
            additionalLineFragmentCount: additionalLineFragmentCount,
            using: typesetter,
            stringLength: stringLength
        )
        updateState(from: typesetResult)
        return typesetResult.lineFragments
    }

    private func typesetLineFragments(
        until condition: TypesetEndCondition,
        additionalLineFragmentCount: Int = 0,
        using typesetter: CTTypesetter,
        stringLength: Int
    ) -> TypesetResult {
        guard constrainingWidth > 0 else {
            return TypesetResult(lineFragments: [], lineFragmentsMap: [:], maximumLineWidth: 0)
        }
        var maximumLineWidth: CGFloat = 0
        var lineFragments: [LineFragment] = []
        var lineFragmentsMap: [LineFragmentID: Int] = [:]
        var remainingAdditionalLineFragmentCount = additionalLineFragmentCount
        let conditionAllowsKeepTypesetting = condition.shouldKeepTypesetting(currentYPosition: nextYPosition, currentCharacterIndex: startOffset)
        var shouldKeepTypesetting = conditionAllowsKeepTypesetting || remainingAdditionalLineFragmentCount > 0
        while startOffset < stringLength && shouldKeepTypesetting, let lineFragment = makeNextLineFragment(using: typesetter) {
            lineFragments.append(lineFragment)
            nextYPosition += lineFragment.scaledSize.height
            startOffset += lineFragment.range.length
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

    private func makeNextLineFragment(using typesetter: CTTypesetter) -> LineFragment? {
        // suggestNextLineBreak(using:) uses CTTypesetterSuggestLineBreak but it may return lines that are longer than our constraining width.
        // In that case we keep removeing characters from the line until we're below the constraining width.
        var length = suggestNextLineBreak(using: typesetter)
        var lineFragment: LineFragment?
        while lineFragment == nil || lineFragment!.scaledSize.width > constrainingWidth {
            let visibleRange = CFRangeMake(startOffset, length)
            lineFragment = makeLineFragment(for: visibleRange, in: typesetter, lineFragmentIndex: lineFragmentIndex, yPosition: nextYPosition)
            length -= 1
        }
        guard let lineFragment else {
            return nil
        }
        let whitespaceLength = lengthOfWhitespace(after: startOffset + length)
        guard whitespaceLength > 0 else {
            return lineFragment
        }
        return lineFragment.withHiddenLength(whitespaceLength)
    }

    private func suggestNextLineBreak(using typesetter: CTTypesetter) -> Int {
        guard let attributedString else {
            return stringLength
        }
        let lineBreakSuggester = LineBreakSuggester(
            lineBreakMode: lineBreakMode,
            typesetter: typesetter,
            attributedString: attributedString,
            constrainingWidth: constrainingWidth
        )
        return lineBreakSuggester.suggestLineBreak(startingAt: startOffset)
    }

    private func lengthOfWhitespace(after location: Int) -> Int {
        guard let attributedString, location < attributedString.length - 1 else {
            return 0
        }
        var nextCharacter = location + 1
        var length = 0
        while attributedString.isWhitespaceCharacter(at: nextCharacter) {
            nextCharacter += 1
            length += 1
        }
        return length
    }

    private func makeLineFragment(
        for visibleRange: CFRange,
        in typesetter: CTTypesetter,
        lineFragmentIndex: Int,
        yPosition: CGFloat
    ) -> LineFragment {
        let line = CTTypesetterCreateLine(typesetter, visibleRange)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        let baseSize = CGSize(width: width, height: height)
        let scaledSize = CGSize(width: width, height: height * lineFragmentHeightMultiplier)
        let id = LineFragmentID(lineId: lineID, lineFragmentIndex: lineFragmentIndex)
        let visibleRange = NSRange(location: visibleRange.location, length: visibleRange.length)
        return LineFragment(
            id: id,
            index: lineFragmentIndex,
            visibleRange: visibleRange,
            line: line,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition
        )
    }
}
