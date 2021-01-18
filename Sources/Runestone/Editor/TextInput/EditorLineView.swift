//
//  EditorLineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

private final class PreparedLine {
    let line: CTLine
    let descent: CGFloat
    let lineHeight: CGFloat
    let yPosition: CGFloat

    init(line: CTLine, descent: CGFloat, lineHeight: CGFloat, yPosition: CGFloat) {
        self.line = line
        self.descent = descent
        self.lineHeight = lineHeight
        self.yPosition = yPosition
    }
}

final class EditorLineView: UIView {
    private(set) var totalHeight: CGFloat = 0

    private var typesetter: CTTypesetter?
    private var preparedLines: [PreparedLine] = []
    private var stringLength = 0

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let context = UIGraphicsGetCurrentContext()!
//        context.setLineWidth(1)
//        context.setStrokeColor(UIColor.red.cgColor)
//        context.stroke(rect.insetBy(dx: 1, dy: 1))
        context.textMatrix = .identity
        context.translateBy(x: 0, y: frame.height)
        context.scaleBy(x: 1, y: -1)
        drawPreparedLines(to: context)
    }

    func prepare(with attributedString: CFAttributedString, lineWidth: CGFloat) {
        preparedLines = []
        totalHeight = 0
        stringLength = CFAttributedStringGetLength(attributedString)
        typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        if let typesetter = typesetter {
            prepareLines(in: typesetter, lineWidth: Double(lineWidth))
        }
    }
}

private extension EditorLineView {
    private func prepareLines(in typesetter: CTTypesetter, lineWidth: Double) {
        var startOffset = 0
        while startOffset < stringLength {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, lineWidth)
            let range = CFRangeMake(startOffset, length)
            let line = CTTypesetterCreateLine(typesetter, range)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let lineHeight = ascent + descent + leading
            let preparedLine = PreparedLine(line: line, descent: descent, lineHeight: lineHeight, yPosition: totalHeight)
            preparedLines.append(preparedLine)
            totalHeight += lineHeight
            startOffset += length
        }
    }

    private func drawPreparedLines(to context: CGContext) {
        for preparedLine in preparedLines {
            let yPosition = preparedLine.descent + (frame.height - preparedLine.yPosition - preparedLine.lineHeight)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(preparedLine.line, context)
        }
    }
}
