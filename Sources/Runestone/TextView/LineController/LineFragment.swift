import CoreText
import Foundation

struct LineFragmentID: Identifiable, Hashable {
    let id: String

    init(lineId: String, lineFragmentIndex: Int) {
        self.id = "\(lineId)[\(lineFragmentIndex)]"
    }
}

extension LineFragmentID: CustomDebugStringConvertible {
    var debugDescription: String {
        id
    }
}

final class LineFragment {
    let id: LineFragmentID
    let index: Int
    let range: NSRange
    let line: CTLine
    let descent: CGFloat
    let baseSize: CGSize
    let scaledSize: CGSize
    let yPosition: CGFloat

    init(id: LineFragmentID, index: Int, range: NSRange, line: CTLine, descent: CGFloat, baseSize: CGSize, scaledSize: CGSize, yPosition: CGFloat) {
        self.id = id
        self.index = index
        self.range = range
        self.line = line
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
    }
}

extension LineFragment: CustomDebugStringConvertible {
    var debugDescription: String {
        "[LineFragment id=\(id) descent=\(descent) baseSize=\(baseSize) scaledSize=\(scaledSize) yPosition=\(yPosition)]"
    }
}
