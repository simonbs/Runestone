import _RunestoneMultiPlatform
import Combine
import CoreText
import Foundation

struct FirstRectProvider<LineManagerType: LineManaging> {
    typealias State = TextContainerInsetReadable

    let state: State
    let lineManager: LineManagerType
    let characterBoundsProvider: CharacterBoundsProviding

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineLocalLocation = range.location - line.location
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        let length = min(lineFragment.range.upperBound - lineLocalLocation, range.length)
        guard let lowerRect = characterBoundsProvider.boundsOfCharacter(atLocation: range.location) else {
            return .zero
        }
        guard let upperRect = characterBoundsProvider.boundsOfCharacter(atLocation: range.location + length) else {
            return .zero
        }
        let width = upperRect.maxX - lowerRect.minX
        return CGRect(x: lowerRect.minX, y: lowerRect.minY, width: width, height: lowerRect.height)
    }
}
