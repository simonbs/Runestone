#if os(iOS)
import Foundation

struct TextPreviewFactory {
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage

    init(lineManager: CurrentValueSubject<LineManager, Never>, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
    }

    func textPreview(containing needleRange: NSRange, peekLength: Int = 50) -> TextPreview? {
        let lines = lineManager.lines(in: needleRange)
        guard !lines.isEmpty else {
            return nil
        }
        let firstLine = lines[0]
        let lastLine = lines[lines.count - 1]
        let minimumLocation = firstLine.location
        let maximumLocation = lastLine.location + lastLine.data.length
        let startLocation = max(needleRange.location - peekLength, minimumLocation)
        let endLocation = min(needleRange.location + needleRange.location + peekLength, maximumLocation)
        let previewLength = endLocation - startLocation
        let previewRange = NSRange(location: startLocation, length: previewLength)
        let lineControllers = lines.map { lineControllerStorage.getOrCreateLineController(for: $0) }
        let localNeedleLocation = needleRange.location - startLocation
        let localNeedleLength = min(needleRange.length, previewRange.length)
        let needleInPreviewRange = NSRange(location: localNeedleLocation, length: localNeedleLength)
        return TextPreview(
            needleRange: needleRange,
            previewRange: previewRange,
            needleInPreviewRange: needleInPreviewRange,
            lineControllers: lineControllers
        )
    }
}
#endif
