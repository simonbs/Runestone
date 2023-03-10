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
    /// ID of the line fragment.
    let id: LineFragmentID
    /// Index of the line fragment within the line.
    let index: Int
    /// The range of the visible characters.
    ///
    /// This range does not contain the hidden characters as defined by ``hiddenLength``.
    let visibleRange: NSRange
    /// The length of the hidden characters.
    ///
    /// Hidden characters are whitespace characters that would be placed at the beginning of the next line fragment if they were rendered. We hide these to align with the behavior of UITextView and NSTextView.
    let hiddenLength: Int
    /// The underlying line.
    let line: CTLine
    /// The lenth of the descent.
    let descent: CGFloat
    /// The non-scaled height of the line fragment.
    let baseSize: CGSize
    /// The scaled height of the line fragment.
    ///
    /// This takes the line height mulitplier into account.
    let scaledSize: CGSize
    /// The y-position of the line fragment.
    ///
    /// This is relative to the beginning of the line.
    let yPosition: CGFloat
    /// Entire range of the line fragment.
    ///
    /// The range also contains the ``hiddenLength`` of the line fragment. That is, the visible content of the line fragment is placed in the range `range.location` to `range.length - hiddenLength`.
    var range: NSRange {
        NSRange(location: visibleRange.location, length: visibleRange.length + hiddenLength)
    }

    convenience init(
        id: LineFragmentID,
        index: Int,
        visibleRange: NSRange,
        line: CTLine,
        descent: CGFloat,
        baseSize: CGSize,
        scaledSize: CGSize,
        yPosition: CGFloat
    ) {
        self.init(
            id: id,
            index: index,
            visibleRange: visibleRange,
            hiddenLength: 0,
            line: line,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition
        )
    }

    private init(
        id: LineFragmentID,
        index: Int,
        visibleRange: NSRange,
        hiddenLength: Int,
        line: CTLine,
        descent: CGFloat,
        baseSize: CGSize,
        scaledSize: CGSize,
        yPosition: CGFloat
    ) {
        self.id = id
        self.index = index
        self.visibleRange = visibleRange
        self.hiddenLength = hiddenLength
        self.line = line
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
    }

    func withHiddenLength(_ hiddenLength: Int) -> LineFragment {
        Self(
            id: id,
            index: index,
            visibleRange: visibleRange,
            hiddenLength: hiddenLength,
            line: line,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition
        )
    }

    func caretLocation(forLineLocalLocation lineLocalLocation: Int) -> Int? {
        let lineFragmentLocalLocation = lineLocalLocation - range.location
        guard lineFragmentLocalLocation >= 0 && lineFragmentLocalLocation <= range.length else {
            return nil
        }
        return min(lineLocalLocation, visibleRange.upperBound)
    }

    func caretRange(forLineLocalRange lineLocalRange: NSRange) -> NSRange? {
        guard let lowerBound = caretLocation(forLineLocalLocation: lineLocalRange.lowerBound) else {
            return nil
        }
        guard let upperBound = caretLocation(forLineLocalLocation: lineLocalRange.upperBound) else {
            return nil
        }
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }
}

extension LineFragment: CustomDebugStringConvertible {
    var debugDescription: String {
        "[LineFragment id=\(id) descent=\(descent) baseSize=\(baseSize) scaledSize=\(scaledSize) yPosition=\(yPosition)]"
    }
}
