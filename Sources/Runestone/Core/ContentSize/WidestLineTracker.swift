import Combine
import Foundation

final class WidestLineTracker {
    @Published private(set) var isLineWidthInvalid = true
    var lineWidth: CGFloat? {
        if let cachedLineWidth {
            return cachedLineWidth
        } else if let trackedLineID, let lineWidth = lineWidths[trackedLineID] {
            let longestLineWidth = lineWidth
            cachedLineWidth = longestLineWidth
            isLineWidthInvalid = false
            return longestLineWidth
        } else {
            trackedLineID = nil
            var longestLineWidth: CGFloat?
            for (lineID, lineWidth) in lineWidths {
                if let currentLongestLineWidth = longestLineWidth {
                    if lineWidth > currentLongestLineWidth {
                        trackedLineID = lineID
                        longestLineWidth = lineWidth
                    }
                } else {
                    trackedLineID = lineID
                    longestLineWidth = lineWidth
                }
            }
            cachedLineWidth = longestLineWidth
            isLineWidthInvalid = false
            return longestLineWidth
        }
    }

    private var trackedLineID: UUID?
    private var lineWidths: [UUID: CGFloat] = [:]
    private var cachedLineWidth: CGFloat?

    func reset() {
        trackedLineID = nil
        lineWidths = [:]
        isLineWidthInvalid = true
    }

    func removeLine(withID lineID: UUID) {
        lineWidths.removeValue(forKey: lineID)
        if lineID == trackedLineID {
            trackedLineID = nil
            cachedLineWidth = nil
            isLineWidthInvalid = true
        }
    }

    func setWidthOfLine(withID lineID: UUID, to newWidth: CGFloat) {
        guard lineWidths[lineID] != newWidth else {
            return
        }
        lineWidths[lineID] = newWidth
        if let trackedLineID {
            let maximumLineWidth = lineWidths[trackedLineID] ?? 0
            if lineID == trackedLineID || newWidth > maximumLineWidth {
                self.trackedLineID = lineID
                cachedLineWidth = nil
                isLineWidthInvalid = true
            }
        } else {
            trackedLineID = lineID
            cachedLineWidth = nil
            isLineWidthInvalid = true
        }
    }
}
