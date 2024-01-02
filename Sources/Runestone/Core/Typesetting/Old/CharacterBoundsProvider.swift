import Combine
import CoreText
import Foundation

final class CharacterBoundsProvider<LineManagerType: LineManaging> {
    private let stringView: StringView
    private let lineManager: LineManagerType
    private var contentArea: CGRect = .zero
    private var cancellables: Set<AnyCancellable> = []

    init(
        stringView: StringView,
        lineManager: LineManagerType,
        contentArea: AnyPublisher<CGRect, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        contentArea.sink { [weak self] contentArea in
            self?.contentArea = contentArea
        }.store(in: &cancellables)
    }

    func boundsOfComposedCharacterSequence(
        atLocation location: Int,
        moveToToNextLineFragmentIfNeeded: Bool
    ) -> CGRect? {
        guard let pair = lineAndActualLocation(
            atLocation: location,
            moveToToNextLineFragmentIfNeeded: moveToToNextLineFragmentIfNeeded
        ) else {
            return nil
        }
        guard location >= 0 && location <= stringView.length else {
            return nil
        }
        let range: NSRange
        if location == stringView.length {
            range = NSRange(location: location - pair.line.location, length: 0)
        } else {
            let composedRange = stringView.string.rangeOfComposedCharacterSequence(at: pair.actualLocation)
            range = NSRange(location: composedRange.location - pair.line.location, length: composedRange.length)
        }
        return boundsOfCharacter(inLineLocalRange: range, in: pair.line)
    }
}

private extension CharacterBoundsProvider {
    private func lineAndActualLocation(
        atLocation location: Int,
        moveToToNextLineFragmentIfNeeded: Bool
    ) -> (line: any Line, actualLocation: Int)? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        guard moveToToNextLineFragmentIfNeeded else {
            return (line, location)
        }
        guard moveToNextLineFragment(forLocation: location - line.location, in: line) else {
            return (line, location)
        }
        return lineAndActualLocation(atLocation: location + 1, moveToToNextLineFragmentIfNeeded: false)
    }

    private func boundsOfCharacter(inLineLocalRange lineLocalRange: NSRange, in line: some Line) -> CGRect? {
        guard let bounds = lineLocalBoundingBox(in: lineLocalRange, localTo: line) else {
            return nil
        }
        let origin = CGPoint(x: bounds.minX + contentArea.origin.x, y: line.yPosition + bounds.minY + contentArea.origin.y)
        return CGRect(origin: origin, size: bounds.size)
    }

    private func lineLocalBoundingBox(in lineLocalRange: NSRange, localTo line: some Line) -> CGRect? {
//        for lineFragment in line.lineFragments {
//            if let insertionPointRange = lineFragment.insertionPointRange(forLineLocalRange: lineLocalRange) {
//                let minXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.lowerBound, nil)
//                let maxXPosition = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.upperBound, nil)
//                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
//                return CGRect(x: minXPosition, y: yPosition, width: maxXPosition - minXPosition, height: lineFragment.baseSize.height)
//            }
//        }
        return nil
    }

    private func moveToNextLineFragment(forLocation location: Int, in line: some Line) -> Bool {
        guard line.numberOfLineFragments > 0 else {
            return false
        }
        let lineFragment = line.lineFragment(containingLocation: location)
        guard lineFragment.index > 0 else {
            return false
        }
        return location == lineFragment.range.location
    }
}
