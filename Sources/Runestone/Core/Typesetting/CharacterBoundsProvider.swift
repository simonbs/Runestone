import Combine
import CoreText
import Foundation

final class CharacterBoundsProvider {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private var contentArea: CGRect = .zero
    private var cancellables: Set<AnyCancellable> = []

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        contentArea: AnyPublisher<CGRect, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        contentArea.sink { [weak self] contentArea in
            self?.contentArea = contentArea
        }.store(in: &cancellables)
    }

    func boundsOfComposedCharacterSequence(atLocation location: Int, moveToToNextLineFragmentIfNeeded: Bool) -> CGRect? {
        guard let pair = lineAndActualLocation(atLocation: location, moveToToNextLineFragmentIfNeeded: moveToToNextLineFragmentIfNeeded) else {
            return nil
        }
        guard location >= 0 && location <= stringView.value.string.length else {
            return nil
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: pair.line)
        let range: NSRange
        if location == stringView.value.string.length {
            range = NSRange(location: location - pair.line.location, length: 0)
        } else {
            let composedRange = stringView.value.string.rangeOfComposedCharacterSequence(at: pair.actualLocation)
            range = NSRange(location: composedRange.location - pair.line.location, length: composedRange.length)
        }
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
        let origin = CGPoint(x: bounds.minX + contentArea.origin.x, y: lineController.line.yPosition + bounds.minY + contentArea.origin.y)
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
