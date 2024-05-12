import _RunestoneObservation
import CoreGraphics
import CoreText
import Foundation

@RunestoneObserver
final class LineTypesetter<StringViewType: StringView, LineType: Line> {
    typealias State = LineHeightMultiplierReadable
    & LineBreakModeReadable
    & IsLineWrappingEnabledReadable
    & TextContainerInsetReadable

    private typealias TypesetPredicate = (TypesetLineFragment) -> Bool

    weak var line: LineType?
    var didInvalidate: (() -> Void)?

    private let state: State
    private let stringView: StringViewType
    private let viewport: Viewport
    private var nextLocation = 0
    private var nextYOffset: CGFloat = 0
    private var nextLineFragmentIndex = 0
    private var isFinishedTypesetting: Bool {
        guard let attributedString else {
            return true
        }
        return nextLocation >= attributedString.length
    }
    private var maximumLineFragmentWidth: CGFloat {
        viewport.width - state.textContainerInset.left - state.textContainerInset.right
    }
    private var typesetter: CTTypesetter? {
        if let typesetter = _typesetter {
            return typesetter
        } else if let attributedString {
            let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
            _typesetter = typesetter
            return typesetter
        } else {
            return nil
        }
    }
    private var _typesetter: CTTypesetter?
    private var attributedString: NSAttributedString? {
        if let attributedString = _attributedString {
            return attributedString
        } else if let line {
            let range = NSRange(location: line.location, length: line.totalLength)
            if let attributedString = stringView.attributedSubstring(in: range) {
                _attributedString = attributedString
                return attributedString
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    private var _attributedString: NSAttributedString?

    init(state: State, stringView: StringViewType, viewport: Viewport) {
        self.state = state
        self.stringView = stringView
        self.viewport = viewport
        observe(state.lineHeightMultiplier) { [unowned self] _, _ in
            self.line?.invalidateTypesetText()
        }
        observe(state.lineBreakMode) { [unowned self] _, _ in
            self.line?.invalidateTypesetText()
        }
        observe(state.isLineWrappingEnabled) { [unowned self] _, _ in
            self.line?.invalidateTypesetText()
        }
        observe(state.textContainerInset) { [unowned self] _, _ in
            self.line?.invalidateTypesetText()
        }
        observe(viewport.size) { [unowned self] oldSize, newSize in
            if oldSize.width != oldSize.width {
                self.line?.invalidateTypesetText()
            }
        }
    }

    func invalidate() {
        nextLocation = 0
        nextYOffset = 0
        nextLineFragmentIndex = 0
        _attributedString = nil
        _typesetter = nil
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
        guard let attributedString, let typesetter else {
            return []
        }
        guard !isFinishedTypesetting else {
            return []
        }
        var lineFragments: [TypesetLineFragment] = []
        var predicateResult = true
        while (nextLocation < attributedString.length && predicateResult) {
            let lineFragment = nextLineFragment(in: attributedString, using: typesetter)
            lineFragments.append(lineFragment)
            nextYOffset += lineFragment.scaledSize.height
            nextLocation += lineFragment.range.length
            nextLineFragmentIndex += 1
            predicateResult = predicate(lineFragment)
        }
        return lineFragments
    }

    private func nextLineFragment(
        in attributedString: NSAttributedString,
        using typesetter: CTTypesetter
    ) -> TypesetLineFragment {
        let length = if state.isLineWrappingEnabled {
            typesetter.suggestLineBreak(
                after: nextLocation,
                in: attributedString,
                using: state.lineBreakMode,
                maximumLineFragmentWidth: maximumLineFragmentWidth
            )
        } else {
            attributedString.length
        }
        let visibleRange = NSRange(location: nextLocation, length: length)
        let cfVisibleRange = CFRangeMake(visibleRange.location, visibleRange.length)
        let line = CTTypesetterCreateLine(typesetter, cfVisibleRange)
        let lineFragment = TypesetLineFragment(
            line: line,
            index: nextLineFragmentIndex,
            visibleRange: visibleRange,
            yPosition: nextYOffset,
            heightMultiplier: state.lineHeightMultiplier
        )
        let hiddenLength = lengthOfWhitespace(after: nextLocation + length)
        return lineFragment.withHiddenLength(hiddenLength)
    }

    private func lengthOfWhitespace(after location: Int) -> Int {
        guard let attributedString else {
            return 0
        }
        guard location < attributedString.length else {
            return 0
        }
        var nextCharacter = location
        var length = 0
        while attributedString.isWhitespaceCharacter(at: nextCharacter) {
            nextCharacter += 1
            length += 1
        }
        return length
    }
}
