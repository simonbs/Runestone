import CoreGraphics
import CoreText
import Foundation

final class LineTextInputProxy {
    var estimatedLineFragmentHeight: CGFloat = 12
    var lineFragmentHeightMultiplier: CGFloat = 1
    var lineFragments: [LineFragment] = []

    func caretRect(atIndex index: Int) -> CGRect {
        for lineFragment in lineFragments {
            let lineRange = CTLineGetStringRange(lineFragment.line)
            let localIndex = index - lineRange.location
            if localIndex >= 0 && localIndex <= lineRange.length {
                let xPosition = CTLineGetOffsetForStringIndex(lineFragment.line, index, nil)
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                return CGRect(x: xPosition, y: yPosition, width: Caret.width, height: lineFragment.baseSize.height)
            }
        }
        let yPosition = (estimatedLineFragmentHeight * lineFragmentHeightMultiplier - estimatedLineFragmentHeight) / 2
        return CGRect(x: 0, y: yPosition, width: Caret.width, height: estimatedLineFragmentHeight)
    }

    func firstRect(for range: NSRange) -> CGRect {
        for lineFragment in lineFragments {
            let line = lineFragment.line
            let lineRange = CTLineGetStringRange(line)
            let index = range.location
            if index >= 0 && index <= lineRange.length {
                let finalIndex = min(lineRange.location + lineRange.length, range.location + range.length)
                let xStart = CTLineGetOffsetForStringIndex(line, index, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, nil)
                return CGRect(x: xStart, y: lineFragment.yPosition, width: xEnd - xStart, height: lineFragment.scaledSize.height)
            }
        }
        return CGRect(x: 0, y: 0, width: 0, height: estimatedLineFragmentHeight * lineFragmentHeightMultiplier)
    }

    func closestIndex(to point: CGPoint) -> Int {
        var closestLineFragment = lineFragments.last
        for lineFragment in lineFragments {
            let lineMaxY = lineFragment.yPosition + lineFragment.scaledSize.height
            if point.y <= lineMaxY {
                closestLineFragment = lineFragment
                break
            }
        }
        if let closestLineFragment = closestLineFragment {
            return CTLineGetStringIndexForPosition(closestLineFragment.line, point)
        } else {
            return 0
        }
    }
}
