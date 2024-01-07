import _RunestoneMultiPlatform
import Combine
import CoreGraphics
import CoreText
import Foundation

final class InsertionPointForegroundRenderer<
    LineManagerType: LineManaging
>: InsertionPointRenderer {
    let needsRender: AnyPublisher<Bool, Never>

    private let lineManager: LineManagerType
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
    private let invisibleCharacterRenderer: InvisibleCharacterRenderer
    private let insertionPointTextColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let insertionPointInvisibleCharacterColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let opacity: CGFloat
    private let _needsRender = CurrentValueSubject<Bool, Never>(false)
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineManager: LineManagerType,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>,
        invisibleCharacterRenderer: InvisibleCharacterRenderer,
        insertionPointTextColor: CurrentValueSubject<MultiPlatformColor, Never>,
        insertionPointInvisibleCharacterColor: CurrentValueSubject<MultiPlatformColor, Never>,
        opacity: CGFloat
    ) {
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.insertionPointShape = insertionPointShape
        self.invisibleCharacterRenderer = invisibleCharacterRenderer
        self.insertionPointTextColor = insertionPointTextColor
        self.insertionPointInvisibleCharacterColor = insertionPointInvisibleCharacterColor
        self.opacity = opacity
        self.needsRender = _needsRender.eraseToAnyPublisher()
        selectedRange.map { $0.location }.removeDuplicates().sink { [weak self] _ in
            self?._needsRender.value = true
        }.store(in: &cancellables)
        Publishers.CombineLatest(
            insertionPointTextColor,
            insertionPointInvisibleCharacterColor
        ).sink { [weak self] _, _ in
            self?._needsRender.value = true
        }.store(in: &cancellables)
    }

    func render(_ rect: CGRect, to context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        defer {
            context.restoreGState()
            _needsRender.value = false
        }
        guard insertionPointShape.value == .block else {
            return
        }
        let location = selectedRange.value.location
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return
        }
        let lineLocalLocation = location - line.location
        let lineFragment = line.lineFragment(containingLocation: lineLocalLocation)
        if invisibleCharacterRenderer.canRenderInvisibleCharacter(
            atLocation: location,
            alignedTo: lineFragment,
            in: line
        ) {
            renderInvisibleCharacter(
                atLocation: location,
                alignedTo: lineFragment,
                in: line,
                within: rect,
                to: context
            )
        } else if lineFragment.line.isEmoji(atLocation: lineLocalLocation) {
            renderOriginalCharacter(
                atLineLocation: lineLocalLocation, 
                in: lineFragment,
                within: rect,
                to: context
            )
        } else {
            renderRecoloredCharacter(
                atLineLocation: lineLocalLocation,
                in: lineFragment,
                within: rect,
                to: context
            )
        }
    }
}

private extension InsertionPointForegroundRenderer {
    private func renderInvisibleCharacter(
        atLocation location: Int,
        alignedTo lineFragment: LineManagerType.LineType.LineFragmentType,
        in line: LineManagerType.LineType,
        within rect: CGRect,
        to context: CGContext
    ) {
        renderImage(
            ofColor: insertionPointInvisibleCharacterColor.value,
            in: rect,
            to: context
        ) { innerContext in
            let offsetX = CTLineGetOffsetForStringIndex(lineFragment.line, location - line.location, nil) * -1
            let offsetY = (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2 * -1
            innerContext.translateBy(x: offsetX, y: offsetY)
            innerContext.asCurrent {
                invisibleCharacterRenderer.renderInvisibleCharacter(
                    atLocation: location, 
                    alignedTo: lineFragment,
                    in: line
                )
            }
        }
    }

    private func renderOriginalCharacter(
        atLineLocation lineLocalLocation: Int,
        in lineFragment: LineManagerType.LineType.LineFragmentType,
        within rect: CGRect,
        to context: CGContext
    ) {
        let offsetX = CTLineGetOffsetForStringIndex(lineFragment.line, lineLocalLocation, nil) * -1
        #if os(iOS)
        let offsetY = (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        #else
        let offsetY = lineFragment.scaledSize.height + (
            lineFragment.scaledSize.height - lineFragment.baseSize.height
        ) / 2
        #endif
        context.setupToDraw(lineFragment)
        context.translateBy(x: offsetX, y: offsetY)
        #if os(macOS)
        context.scaleBy(x: 1, y: -1)
        #endif
        CTLineDraw(lineFragment.line, context)
    }

    private func renderRecoloredCharacter(
        atLineLocation lineLocalLocation: Int,
        in lineFragment: LineManagerType.LineType.LineFragmentType,
        within rect: CGRect,
        to context: CGContext
    ) {
        renderImage(
            ofColor: insertionPointTextColor.value,
            in: rect,
            to: context
        ) { innerContext in
            renderOriginalCharacter(
                atLineLocation: lineLocalLocation, 
                in: lineFragment,
                within: rect,
                to: innerContext
            )
        }
    }

    private func renderImage(
        ofColor color: MultiPlatformColor,
        in rect: CGRect,
        to context: CGContext,
        using renderer: (CGContext) -> Void
    ) {
        guard let image = ImageRenderer.renderImage(ofSize: rect.size, using: renderer) else {
            return
        }
        context.saveGState()
        context.clip(to: rect, mask: image)
        context.setFillColor(color.cgColor)
        context.fill(rect)
        context.restoreGState()
    }
}
