import CoreGraphics
import CoreText
import Foundation

final class LineTypesetter: LineTypesetting {
    typealias State = LineHeightMultiplierReadable
    & LineBreakModeReadable
    & IsLineWrappingEnabledReadable

    private typealias TypesetPredicate = (TypesetLineFragment) -> Bool


    private let state: State
    private let viewport: Viewport
    private let attributedString: NSAttributedString
    private let typesetter: CTTypesetter
    private var nextLocation = 0
    private var nextYOffset: CGFloat = 0
    private var index = 0
    private var isFinishedTypesetting: Bool {
        nextLocation >= attributedString.length
    }

    init(state: State, viewport: Viewport, attributedString: NSAttributedString) {
        self.state = state
        self.viewport = viewport
        self.attributedString = attributedString
        self.typesetter = CTTypesetterCreateWithAttributedString(attributedString)
    }

    func typesetText(toYOffset yOffset: CGFloat) -> [TypesetLineFragment] {
        guard yOffset > nextYOffset else {
            return []
        }
        return typesetLineFragments { lineFragment in
            lineFragment.yPosition + lineFragment.scaledSize.height < yOffset
        }
    }

    func typesetText(toLocation location: Int) -> [TypesetLineFragment] {
        guard location > nextLocation else {
            return []
        }
        return typesetLineFragments(while: { lineFragment in
            lineFragment.range.upperBound < location
        }, additionalLineFragmentCount: 1)
    }
}

private extension LineTypesetter {
    private func typesetLineFragments(
        while predicate: TypesetPredicate,
        additionalLineFragmentCount: Int
    ) -> [TypesetLineFragment] {
        var remainingAdditionalLineFragments = additionalLineFragmentCount
        var isTakingAdditionalLineFragments = false
        return typesetLineFragments { lineFragment in
            if isTakingAdditionalLineFragments {
                if remainingAdditionalLineFragments > 0 {
                    remainingAdditionalLineFragments -= 1
                    return true
                } else {
                    return false
                }
            } else if predicate(lineFragment) {
                return true
            } else {
                isTakingAdditionalLineFragments = true
                return true
            }
        }
    }

    private func typesetLineFragments(while predicate: TypesetPredicate) -> [TypesetLineFragment] {
        guard !isFinishedTypesetting else {
            return []
        }
        var lineFragments: [TypesetLineFragment] = []
        var predicateResult = true
        while (nextLocation < attributedString.length && predicateResult) {
            let lineFragment = nextLineFragment(from: typesetter)
            lineFragments.append(lineFragment)
            nextYOffset += lineFragment.scaledSize.height
            nextLocation += lineFragment.range.length
            index += 1
            predicateResult = predicate(lineFragment)
        }
        return lineFragments
    }

    private func nextLineFragment(from typesetter: CTTypesetter) -> TypesetLineFragment {
        let length = if state.isLineWrappingEnabled {
            typesetter.suggestLineBreak(
                after: nextLocation,
                in: attributedString,
                using: state.lineBreakMode,
                maximumLineFragmentWidth: viewport.width
            )
        } else {
            attributedString.length
        }
        let visibleRange = NSRange(location: nextLocation, length: length)
        let cfVisibleRange = CFRangeMake(visibleRange.location, visibleRange.length)
        let line = CTTypesetterCreateLine(typesetter, cfVisibleRange)
        let lineFragment = TypesetLineFragment(
            line: line,
            index: index,
            visibleRange: visibleRange,
            yPosition: nextYOffset,
            heightMultiplier: state.lineHeightMultiplier
        )
        let hiddenLength = lengthOfWhitespace(after: nextLocation + length)
        return lineFragment.withHiddenLength(hiddenLength)
    }

    private func lengthOfWhitespace(after location: Int) -> Int {
        guard location < attributedString.length - 1 else {
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
}
