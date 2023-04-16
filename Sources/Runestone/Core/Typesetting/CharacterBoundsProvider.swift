import Combine
import CoreText
import Foundation

struct CharacterBoundsProvider {
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    let lineControllerStorage: LineControllerStorage
    let contentArea: ContentArea

    func boundsOfComposedCharacterSequence(atLocation location: Int, moveToToNextLineFragmentIfNeeded: Bool) -> CGRect? {
        guard location >= 0 && location < stringView.value.string.length else {
            return nil
        }
        guard let pair = lineAndActualLocation(atLocation: location, moveToToNextLineFragmentIfNeeded: moveToToNextLineFragmentIfNeeded) else {
            return nil
        }
        let rawRange = stringView.value.string.rangeOfComposedCharacterSequence(at: pair.actualLocation)
        let range = NSRange(location: rawRange.location - pair.line.location, length: rawRange.length)
        let lineController = lineControllerStorage.getOrCreateLineController(for: pair.line)
        return boundsOfCharacter(inLineLocalRange: range, in: lineController)
    }
}

private extension CharacterBoundsProvider {
    private func lineAndActualLocation(atLocation location: Int, moveToToNextLineFragmentIfNeeded: Bool) -> (line: LineNode, actualLocation: Int)? {
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
            return nil
        }
        if moveToToNextLineFragmentIfNeeded && moveToNextLineFragment(forLocation: location - line.location, in: line) {
            return lineAndActualLocation(atLocation: location + 1, moveToToNextLineFragmentIfNeeded: false)
        } else {
            return (line, location)
        }
    }

    private func boundsOfCharacter(inLineLocalRange lineLocalRange: NSRange, in lineController: LineController) -> CGRect? {
        guard let bounds = lineLocalBoundingBox(in: lineLocalRange, localTo: lineController) else {
            return nil
        }
        let originAdjustment = contentArea.rawValue.value.origin
        let origin = CGPoint(x: bounds.minX + originAdjustment.x, y: lineController.line.yPosition + bounds.minY + originAdjustment.y)
        return CGRect(origin: origin, size: bounds.size)
    }

    private func lineLocalBoundingBox(in lineLocalRange: NSRange, localTo lineController: LineController) -> CGRect? {
        for lineFragment in lineController.lineFragments {
            if let insertionPointRange = lineFragment.insertionPointRange(forLineLocalRange: lineLocalRange) {
                let minXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.lowerBound, nil)
                let maxXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.upperBound, nil)
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                return CGRect(x: minXPosition, y: yPosition, width: maxXPosition - minXPosition, height: lineFragment.baseSize.height)
            }
        }
        return nil
    }

    private func moveToNextLineFragment(forLocation location: Int, in line: LineNode) -> Bool {
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        guard lineController.numberOfLineFragments > 0 else {
            return false
        }
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location) else {
            return false
        }
        guard lineFragmentNode.index > 0 else {
            return false
        }
        return location == lineFragmentNode.data.lineFragment?.range.location
    }
}
