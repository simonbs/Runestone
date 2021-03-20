//
//  LineTextInputProxy.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

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

    func selectionRects(in range: NSRange) -> [LineFragmentSelectionRect] {
        guard !lineFragments.isEmpty else {
            let rect = CGRect(x: 0, y: 0, width: 0, height: estimatedLineFragmentHeight * lineFragmentHeightMultiplier)
            return [LineFragmentSelectionRect(rect: rect, range: range)]
        }
        var selectionRects: [LineFragmentSelectionRect] = []
        for lineFragment in lineFragments {
            let line = lineFragment.line
            let cfLineRange = CTLineGetStringRange(line)
            let lineRange = NSRange(location: cfLineRange.location, length: cfLineRange.length)
            let selectionIntersection = range.intersection(lineRange)
            if let selectionIntersection = selectionIntersection {
                let xStart = CTLineGetOffsetForStringIndex(line, selectionIntersection.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, selectionIntersection.location + selectionIntersection.length, nil)
                let yPosition = lineFragment.yPosition
                let rect = CGRect(x: xStart, y: yPosition, width: xEnd - xStart, height: lineFragment.scaledSize.height)
                let selectionRect = LineFragmentSelectionRect(rect: rect, range: selectionIntersection)
                selectionRects.append(selectionRect)
            }
        }
        return selectionRects
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
