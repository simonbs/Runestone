//
//  LineTypesetter.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import Foundation
import CoreGraphics
import CoreText

private final class TypesetResult {
    let typesetLines: [TypesetLine]
    let maximumLineWidth: CGFloat

    init(typesetLines: [TypesetLine], maximumLineWidth: CGFloat) {
        self.typesetLines = typesetLines
        self.maximumLineWidth = maximumLineWidth
    }
}

final class LineTypesetter {
    var constrainingWidth: CGFloat?
    private(set) var preferredSize: CGSize?
    private(set) var typesetLines: [TypesetLine] = []

    func typeset(_ attributedString: CFAttributedString) {
        reset()
        let stringLength = CFAttributedStringGetLength(attributedString)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let typesetResult = self.typesetLines(in: typesetter, stringLength: stringLength)
        if let typesetResult = typesetResult, let lastLine = typesetResult.typesetLines.last {
            typesetLines = typesetResult.typesetLines
            preferredSize = CGSize(width: typesetResult.maximumLineWidth, height: lastLine.yPosition + lastLine.size.height)
        }
    }
}

private extension LineTypesetter {
    private func reset() {
        typesetLines = []
        preferredSize = nil
    }

    private func createAttributedString(from string: String) -> CFAttributedString? {
        if let attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.utf16.count) {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string as CFString)
            return attributedString
        } else {
            return nil
        }
    }

    private func typesetLines(in typesetter: CTTypesetter, stringLength: Int) -> TypesetResult? {
        guard stringLength > 0 else {
            return nil
        }
        if let constrainingWidth = constrainingWidth {
            return typesetWrappingLines(in: typesetter, stringLength: stringLength, constrainingWidth: constrainingWidth)
        } else {
            return typesetNonWrappingLine(in: typesetter, stringLength: stringLength)
        }
    }

    private func typesetWrappingLines(in typesetter: CTTypesetter, stringLength: Int, constrainingWidth: CGFloat) -> TypesetResult {
        var nextYPosition: CGFloat = 0
        var startOffset = 0
        var maximumLineWidth: CGFloat = 0
        var typesetLines: [TypesetLine] = []
        while startOffset < stringLength {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(constrainingWidth))
            let range = CFRangeMake(startOffset, length)
            let typesetLine = createTypesetLine(for: range, in: typesetter, yPosition: nextYPosition)
            typesetLines.append(typesetLine)
            nextYPosition += typesetLine.size.height
            startOffset += length
            if typesetLine.size.width > maximumLineWidth {
                maximumLineWidth = typesetLine.size.width
            }
        }
        return TypesetResult(typesetLines: typesetLines, maximumLineWidth: maximumLineWidth)
    }

    private func typesetNonWrappingLine(in typesetter: CTTypesetter, stringLength: Int) -> TypesetResult {
        let range = CFRangeMake(0, stringLength)
        let typesetLine = createTypesetLine(for: range, in: typesetter, yPosition: 0)
        return TypesetResult(typesetLines: [typesetLine], maximumLineWidth: typesetLine.size.width)
    }

    private func createTypesetLine(for range: CFRange, in typesetter: CTTypesetter, yPosition: CGFloat) -> TypesetLine {
        let line = CTTypesetterCreateLine(typesetter, range)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        let size = CGSize(width: width, height: height)
        return TypesetLine(line: line, descent: descent, size: size, yPosition: yPosition)
    }
}
