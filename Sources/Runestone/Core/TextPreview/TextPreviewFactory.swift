import Combine
import Foundation

struct TextPreviewFactory<LineManagerType: LineManaging> {
    let lineManager: LineManagerType

    func textPreview(containing needleRange: NSRange, peekLength: Int = 50) -> TextPreview? {
//        let lines = lineManager.lines(in: needleRange)
//        guard !lines.isEmpty else {
//            return nil
//        }
//        let firstLine = lines[0]
//        let lastLine = lines[lines.count - 1]
//        let minimumLocation = firstLine.location
//        let maximumLocation = lastLine.location + lastLine.data.length
//        let startLocation = max(needleRange.location - peekLength, minimumLocation)
//        let endLocation = min(needleRange.location + needleRange.location + peekLength, maximumLocation)
//        let previewLength = endLocation - startLocation
//        let previewRange = NSRange(location: startLocation, length: previewLength)
//        let lineControllers = lines.map { lineControllerStore.getOrCreateLineController(for: $0) }
//        let localNeedleLocation = needleRange.location - startLocation
//        let localNeedleLength = min(needleRange.length, previewRange.length)
//        let needleInPreviewRange = NSRange(location: localNeedleLocation, length: localNeedleLength)
//        return TextPreview(
//            needleRange: needleRange,
//            previewRange: previewRange,
//            needleInPreviewRange: needleInPreviewRange,
//            lineControllers: lineControllers
//        )
        return nil
    }
}
