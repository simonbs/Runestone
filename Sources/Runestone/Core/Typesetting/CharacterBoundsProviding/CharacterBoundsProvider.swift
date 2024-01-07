import CoreText
import Foundation

struct CharacterBoundsProvider<
    StringViewType: StringView, 
    LineManagerType: LineManaging
>: CharacterBoundsProviding {
    typealias State = TextContainerInsetReadable

    let state: State
    let stringView: StringViewType
    let lineManager: LineManagerType

    func boundsOfCharacter(atLocation location: Int) -> CGRect? {
        guard location >= 0 && location < stringView.length else {
            return nil
        }
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let range = stringView.rangeOfComposedCharacterSequence(at: location - line.location)
        let lineFragment = line.lineFragment(containingLocation: range.lowerBound)
        let minXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, range.lowerBound, nil)
        let maxXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, range.upperBound, nil)
        let lineFragmentHeightDelta = lineFragment.scaledSize.height - lineFragment.baseSize.height
        let minYPosition = line.yPosition + lineFragment.yPosition + lineFragmentHeightDelta / 2
        let origin = CGPoint(x: minXPosition, y: minYPosition)
        let size = CGSize(width: maxXPosition - minXPosition, height: lineFragment.baseSize.height)
        return CGRect(origin: origin, size: size)
    }
}
