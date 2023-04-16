import Combine
import CoreText
import Foundation

struct InsertionPointFrameFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    let characterBoundsProvider: CharacterBoundsProvider
    let lineControllerStorage: LineControllerStorage
    let shape: CurrentValueSubject<InsertionPointShape, Never>
    let contentArea: CurrentValueSubject<CGRect, Never>
    let estimatedLineHeight: EstimatedLineHeight
    let estimatedCharacterWidth: CurrentValueSubject<CGFloat, Never>

    func frameOfInsertionPoint(at location: Int) -> CGRect {
        switch shape.value {
        case .verticalBar:
            return verticalBarInsertionPointFrame(at: location)
        case .underline:
            return underlineInsertionPointFrame(at: location)
        case .block:
            return blockInsertionPointFrame(at: location)
        }
    }
}

extension InsertionPointFrameFactory {
    private var fixedLength: CGFloat {
        #if os(iOS)
        return 2
        #else
        return 1
        #endif
    }

    private func verticalBarInsertionPointFrame(at location: Int) -> CGRect {
        let blockFrame = blockInsertionPointFrame(at: location)
        return CGRect(x: blockFrame.minX, y: blockFrame.minY, width: fixedLength, height: blockFrame.height)
    }

    private func underlineInsertionPointFrame(at location: Int) -> CGRect {
        let blockFrame = blockInsertionPointFrame(at: location)
        return CGRect(x: blockFrame.minX, y: blockFrame.maxY - fixedLength, width: blockFrame.width, height: fixedLength)
    }

    private func blockInsertionPointFrame(at location: Int) -> CGRect {
        if let bounds = characterBoundsProvider.boundsOfComposedCharacterSequence(atLocation: location, moveToToNextLineFragmentIfNeeded: true) {
            let width = displayableCharacterWidth(forCharacterAtLocation: location, widthActualWidth: bounds.width)
            return CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
        } else if location == stringView.value.string.length, let bounds = getLastCharacterBounds() {
            return bounds
        } else {
            let origin = CGPoint(x: contentArea.value.minX, y: contentArea.value.minY)
            let size = CGSize(width: estimatedCharacterWidth.value, height: estimatedLineHeight.rawValue.value)
            return CGRect(origin: origin, size: size)
        }
    }

    private func displayableCharacterWidth(forCharacterAtLocation location: Int, widthActualWidth actualWidth: CGFloat) -> CGFloat {
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
            return actualWidth
        }
        // If the insertion point is placed at the last character in a line, i.e. berfore a line break, then we make sure to return the estimated character width.
        let lineLocalLocation = location - line.location
        if lineLocalLocation == line.data.length {
            return estimatedCharacterWidth.value
        } else {
            return actualWidth
        }
    }

    private func getLastCharacterBounds() -> CGRect? {
        let line = lineManager.value.lastLine
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let location = stringView.value.string.length
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location - line.location) else {
            return nil
        }
        guard let lineFragment = lineFragmentNode.data.lineFragment else {
            return nil
        }
        let offsetX = contentArea.value.minX + CTLineGetOffsetForStringIndex(lineFragment.line, lineFragment.visibleRange.upperBound, nil)
        let offsetY = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        return CGRect(x: offsetX, y: offsetY, width: estimatedCharacterWidth.value, height: estimatedLineHeight.rawValue.value)
    }
}
