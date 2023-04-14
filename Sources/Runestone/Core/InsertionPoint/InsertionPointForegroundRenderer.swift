import Combine
import CoreGraphics
import CoreText
import Foundation

final class InsertionPointForegroundRenderer {
    var defaultColor: MultiPlatformColor = .background
    var invisibleCharactersColor: MultiPlatformColor = .background

    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
    private let invisibleCharacterRenderer: InvisibleCharacterRenderer

    init(
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>,
        invisibleCharacterRenderer: InvisibleCharacterRenderer
    ) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.selectedRange = selectedRange
        self.insertionPointShape = insertionPointShape
        self.invisibleCharacterRenderer = invisibleCharacterRenderer
    }

    func render(_ rect: CGRect, to context: CGContext) {
        guard insertionPointShape.value == .block else {
            return
        }
        let location = selectedRange.value.location
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
            return
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocalLocation = location - line.location
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return
        }
        guard let lineFragment = lineFragmentNode.data.lineFragment else {
            return
        }
        if invisibleCharacterRenderer.canRenderInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line) {
            renderInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line, within: rect, to: context)
        } else if lineFragment.line.isEmoji(atLocation: lineLocalLocation) {
            renderOriginalCharacter(atLineLocation: lineLocalLocation, in: lineFragment, within: rect, to: context)
        } else {
            renderRecoloredCharacter(atLineLocation: lineLocalLocation, in: lineFragment, within: rect, to: context)
        }
    }
}

private extension InsertionPointForegroundRenderer {
    private func renderInvisibleCharacter(
        atLocation location: Int,
        alignedTo lineFragment: LineFragment,
        in line: LineNode,
        within rect: CGRect,
        to context: CGContext
    ) {
        renderImage(ofColor: invisibleCharactersColor, in: rect, to: context) { innerContext in
            let offsetX = CTLineGetOffsetForStringIndex(lineFragment.line, location - line.location, nil) * -1
            let offsetY = (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2 * -1
            innerContext.translateBy(x: offsetX, y: offsetY)
            innerContext.asCurrent {
                invisibleCharacterRenderer.renderInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line)
            }
        }
    }

    private func renderOriginalCharacter(
        atLineLocation lineLocalLocation: Int,
        in lineFragment: LineFragment,
        within rect: CGRect,
        to context: CGContext
    ) {
        let offsetX = CTLineGetOffsetForStringIndex(lineFragment.line, lineLocalLocation, nil) * -1
        let offsetY = lineFragment.scaledSize.height + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        context.setupToDraw(lineFragment)
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(lineFragment.line, context)
    }

    private func renderRecoloredCharacter(
        atLineLocation lineLocalLocation: Int,
        in lineFragment: LineFragment,
        within rect: CGRect,
        to context: CGContext
    ) {
        renderImage(ofColor: defaultColor, in: rect, to: context) { innerContext in
            renderOriginalCharacter(atLineLocation: lineLocalLocation, in: lineFragment, within: rect, to: innerContext)
        }
    }

    private func renderImage(ofColor color: MultiPlatformColor, in rect: CGRect, to context: CGContext, using renderer: (CGContext) -> Void) {
        if let image = ImageRenderer.renderImage(ofSize: rect.size, using: renderer) {
            RecolorImageRenderer.render(image, withColor: color, in: rect, to: context)
        }
    }
}
