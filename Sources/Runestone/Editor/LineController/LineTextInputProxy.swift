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
    var defaultLineHeight: CGFloat = 12

    private let lineTypesetter: LineTypesetter
    private var typesetLines: [TypesetLine] {
        return lineTypesetter.typesetLines
    }

    init(lineTypesetter: LineTypesetter) {
        self.lineTypesetter = lineTypesetter
    }

    func caretRect(atIndex index: Int) -> CGRect {
        for typesetLine in typesetLines {
            let lineRange = CTLineGetStringRange(typesetLine.line)
            let localIndex = index - lineRange.location
            if localIndex >= 0 && localIndex <= lineRange.length {
                let xPos = CTLineGetOffsetForStringIndex(typesetLine.line, index, nil)
                return CGRect(x: xPos, y: typesetLine.yPosition, width: Caret.width, height: typesetLine.size.height)
            }
        }
        return CGRect(x: 0, y: 0, width: Caret.width, height: defaultLineHeight)
    }

    func selectionRects(in range: NSRange) -> [TypesetLineSelectionRect] {
        var selectionRects: [TypesetLineSelectionRect] = []
        for preparedLine in typesetLines {
            let line = preparedLine.line
            let _lineRange = CTLineGetStringRange(line)
            let lineRange = NSRange(location: _lineRange.location, length: _lineRange.length)
            let selectionIntersection = range.intersection(lineRange)
            if let selectionIntersection = selectionIntersection {
                let xStart = CTLineGetOffsetForStringIndex(line, selectionIntersection.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, selectionIntersection.location + selectionIntersection.length, nil)
                let yPos = preparedLine.yPosition
                let rect = CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: preparedLine.size.height)
                let selectionRect = TypesetLineSelectionRect(rect: rect, range: selectionIntersection)
                selectionRects.append(selectionRect)
            }
        }
        return selectionRects
    }

    func firstRect(for range: NSRange) -> CGRect {
        for preparedLine in typesetLines {
            let line = preparedLine.line
            let lineRange = CTLineGetStringRange(line)
            let index = range.location
            if index >= 0 && index <= lineRange.length {
                let finalIndex = min(lineRange.location + lineRange.length, range.location + range.length)
                let xStart = CTLineGetOffsetForStringIndex(line, index, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, nil)
                return CGRect(x: xStart, y: preparedLine.yPosition, width: xEnd - xStart, height: preparedLine.size.height)
            }
        }
        return CGRect(x: 0, y: 0, width: 0, height: defaultLineHeight)
    }

    func closestIndex(to point: CGPoint) -> Int {
        var closestPreparedLine = typesetLines.last
        for preparedLine in typesetLines {
            let lineMaxY = preparedLine.yPosition + preparedLine.size.height
            if point.y <= lineMaxY {
                closestPreparedLine = preparedLine
                break
            }
        }
        if let closestPreparedLine = closestPreparedLine {
            return CTLineGetStringIndexForPosition(closestPreparedLine.line, point)
        } else {
            return 0
        }
    }
}
