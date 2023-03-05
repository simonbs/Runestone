#if os(iOS)
import Foundation

struct FirstRectProvider {
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private let textContainerWidth: CGFloat
    private let textContainerInset: MultiPlatformEdgeInsets

    init(
        lineManager: LineManager,
        lineControllerStorage: LineControllerStorage,
        textContainerWidth: CGFloat,
        textContainerInset: MultiPlatformEdgeInsets
    ) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.textContainerWidth = textContainerWidth
        self.textContainerInset = textContainerInset
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let lineContentsRect = lineController.firstRect(for: localRange)
        let xPosition = lineContentsRect.minX + textContainerInset.left
        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.top
        let width = min(lineContentsRect.width, textContainerWidth)
        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }
}
#endif
