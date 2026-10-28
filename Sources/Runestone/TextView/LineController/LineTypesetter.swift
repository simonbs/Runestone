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
    private struct Configuration: Equatable {
        let width: CGFloat
        let mode: LineBreakMode
        let heightMultiplier: CGFloat
    }

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
    private var preparedConfiguration: Configuration?
    private var currentConfiguration: Configuration {
        Configuration(width: constrainingWidth, mode: lineBreakMode, heightMultiplier: lineFragmentHeightMultiplier)
    }

    init(lineID: String) {
        self.lineID = lineID
    }

    func reset() {
        preparedConfiguration = nil
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
        if lineFragments.isEmpty { preparedConfiguration = currentConfiguration }
        self.attributedString = attributedString
        stringLength = CFAttributedStringGetLength(attributedString)
        typesetter = CTTypesetterCreateWithAttributedString(stringForTypesetting(attributedString))
    }

    /// The controller grants one-shot reuse only for a clean text invalidation.
    /// Keep the previous input local to this call; ordinary preparation owns no
    /// extra snapshot and performs no prefix validation.
    func reprepareToTypeset(_ string: NSAttributedString, previous: NSAttributedString, prefixLimit: Int) -> [LineFragment] {
        var count = 0
        if preparedConfiguration == currentConfiguration, lineBreakMode == .byWordWrapping,
           constrainingWidth.isFinite, constrainingWidth > 0,
           lineFragmentHeightMultiplier.isFinite, lineFragmentHeightMultiplier > 0 {
            count = LinePrefixReuse.count(from: previous, to: string, fragments: lineFragments, limit: prefixLimit)
        }
        let prefix = Array(lineFragments.prefix(count))
        reset()
        prepareToTypeset(string)
        guard let typesetter else {
            return []
        }
        for fragment in prefix {
            let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
            let rebuilt = fragment.withLine(CTTypesetterCreateLine(typesetter, range))
            lineFragments.append(rebuilt)
            lineFragmentsMap[rebuilt.id] = rebuilt.index
            maximumLineWidth = max(maximumLineWidth, rebuilt.scaledSize.width)
        }
        startOffset = lineFragments.last?.range.upperBound ?? 0
        nextYPosition = lineFragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
        lineFragmentIndex = lineFragments.count
        return lineFragments
    }

    // The caller has verified that only appearance attributes changed. Rebuild
    // drawing runs with the full string so CoreText keeps line-local UTF-16 indices.
    // Retain the measured prefix and its continuation state, including hidden spaces.
    func refreshAppearance(_ attributedString: NSAttributedString) -> [LineFragment] {
        prepareToTypeset(attributedString)
        guard let typesetter else {
            return []
        }
        lineFragments = lineFragments.map { fragment in
            let range = CFRange(location: fragment.visibleRange.location, length: fragment.visibleRange.length)
            return fragment.withLine(CTTypesetterCreateLine(typesetter, range))
        }
        if isFinishedTypesetting {
            self.attributedString = nil
            self.typesetter = nil
        }
        return lineFragments
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
    private func stringForTypesetting(_ string: NSAttributedString) -> NSAttributedString {
        // Keep token backgrounds out of CTLineDraw so they cannot cover search or
        // marked-text highlights. The renderer paints these backgrounds first.
        // Preserve the original attributes for clients of StringSyntaxHighlighter.
        var copy: NSMutableAttributedString?
        string.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            guard let value else {
                return
            }
            if copy == nil {
                copy = NSMutableAttributedString(attributedString: string)
            }
            copy?.removeAttribute(.backgroundColor, range: range)
            copy?.addAttribute(.tokenBackgroundColor, value: value, range: range)
        }
        return copy ?? string
    }

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
        guard let attributedString, startOffset < stringLength,
              let string = CFAttributedStringGetString(attributedString) else { return nil }
        let suggestedLength = suggestNextLineBreak(using: typesetter)
        let proposedEnd = startOffset + min(max(0, suggestedLength), stringLength - startOffset)
        var end = composedBoundary(atOrBefore: proposedEnd, in: string)
        if end <= startOffset {
            let first = composedRange(at: startOffset, in: string)
            end = first.location + first.length
        }
        var minimumEnd: Int?
        while true {
            let visibleRange = CFRange(location: startOffset, length: end - startOffset)
            let fragment = makeLineFragment(for: visibleRange, in: typesetter,
                                            lineFragmentIndex: lineFragmentIndex, yPosition: nextYPosition)
            if fragment.scaledSize.width <= constrainingWidth {
                let hiddenLength = lengthOfWhitespace(startingAt: end, in: string)
                return hiddenLength > 0 ? fragment.withHiddenLength(hiddenLength) : fragment
            }
            if minimumEnd == nil {
                let first = composedRange(at: startOffset, in: string)
                minimumEnd = first.location + first.length
            }
            // A single oversized grapheme must overflow rather than disappear or
            // make no progress. Zero-length CoreText ranges mean the whole suffix.
            guard let minimumEnd, end > minimumEnd else {
                let hiddenLength = lengthOfWhitespace(startingAt: end, in: string)
                return hiddenLength > 0 ? fragment.withHiddenLength(hiddenLength) : fragment
            }
            let last = composedRange(at: end - 1, in: string)
            end = max(minimumEnd, last.location)
        }
    }

    /// Fast ASCII boundaries avoid asking Unicode segmentation about ordinary
    /// code on every fragment. Adjacent non-ASCII units use composed sequences.
    private func composedBoundary(atOrBefore location: Int, in string: CFString) -> Int {
        guard location > 0, location < stringLength else {
            return location
        }
        let previous = CFStringGetCharacterAtIndex(string, location - 1)
        let current = CFStringGetCharacterAtIndex(string, location)
        if previous < 128 && current < 128 {
            return previous == 13 && current == 10 ? location - 1 : location
        }
        return composedRange(at: location, in: string).location
    }

    private func composedRange(at location: Int, in string: CFString) -> CFRange {
        let unit = CFStringGetCharacterAtIndex(string, location)
        if unit == 10, location > 0, CFStringGetCharacterAtIndex(string, location - 1) == 13 {
            return CFRange(location: location - 1, length: 2)
        }
        if location + 1 < stringLength {
            let next = CFStringGetCharacterAtIndex(string, location + 1)
            if unit == 13 && next == 10 {
                return CFRange(location: location, length: 2)
            }
            if unit < 128 && next < 128,
               location == 0 || CFStringGetCharacterAtIndex(string, location - 1) < 128 {
                return CFRange(location: location, length: 1)
            }
        } else if unit < 128, location == 0 || CFStringGetCharacterAtIndex(string, location - 1) < 128 {
            return CFRange(location: location, length: 1)
        }
        return CFStringGetRangeOfComposedCharactersAtIndex(string, location)
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

    private func lengthOfWhitespace(startingAt location: Int, in string: CFString) -> Int {
        guard let attributedString, location < stringLength else {
            return 0
        }
        var next = location
        while attributedString.isWhitespaceCharacter(at: next) {
            next += 1
        }
        guard next > location else {
            return 0
        }
        // A space followed by a combining mark belongs to one visible grapheme;
        // hiding only the space would leave the next fragment inside that cluster.
        return max(0, composedBoundary(atOrBefore: next, in: string) - location)
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
