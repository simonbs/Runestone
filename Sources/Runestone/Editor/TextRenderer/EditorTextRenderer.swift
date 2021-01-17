//
//  EditorTextRenderer.swift
//  
//
//  Created by Simon Støvring on 06/01/2021.
//

import UIKit

struct EditorTextRendererSelectionRect {
    let rect: CGRect
    let range: NSRange

    init(rect: CGRect, range: NSRange) {
        self.rect = rect
        self.range = range
    }
}

final class EditorTextRenderer {
    var isContentInvalid = true
    var font: UIFont?
    var textColor: UIColor?
    var constrainingWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            if constrainingWidth != oldValue {
                _preferredSize = nil
            }
        }
    }
    var preferredSize: CGSize {
        if let preferredSize = _preferredSize {
            return preferredSize
        } else if isEmpty, let font = font {
            let height = font.lineHeight
            let preferredSize = CGSize(width: constrainingWidth, height: height)
            _preferredSize = preferredSize
            return preferredSize
        } else if let framesetter = framesetter {
            let constrainingSize = CGSize(width: constrainingWidth, height: .greatestFiniteMagnitude)
            let preferredSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constrainingSize, nil)
            _preferredSize = preferredSize
            return preferredSize
        } else if let font = font {
            let preferredSize = CGSize(width: constrainingWidth, height: font.lineHeight)
            _preferredSize = preferredSize
            return preferredSize
        } else {
            return .zero
        }
    }

    private var attributedString: CFMutableAttributedString?
    private var framesetter: CTFramesetter? {
        if let framesetter = _framesetter {
            return framesetter
        } else if let attributedString = attributedString {
            _framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            return _framesetter
        } else {
            return nil
        }
    }
    private var textFrame: CTFrame? {
        if let frame = _textFrame {
            return frame
        } else if let framesetter = framesetter {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height))
            _textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            return _textFrame
        } else {
            return nil
        }
    }
    private var _framesetter: CTFramesetter?
    private var _textFrame: CTFrame?
    private var _preferredSize: CGSize?
    private var isEmpty = true
    private var string: NSString?
    private var attributes: [EditorTextRendererAttributes] = []

    func setString(_ string: NSString, attributes: [EditorTextRendererAttributes]) {
        guard string != self.string || attributes != self.attributes else {
            return
        }
        self.string = string
        self.attributes = attributes
        _preferredSize = nil
        _framesetter = nil
        _textFrame = nil
        isEmpty = string.length == 0
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.length)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string)
            applyDefaultFont()
            applyDefaultTextColor()
            applyAttributes()
        }
    }

    func draw(in context: CGContext) {
        if let textFrame = textFrame {
            CTFrameDraw(textFrame, context)
        }
    }

    func caretRect(atIndex index: Int) -> CGRect {
        guard let textFrame = textFrame else {
            return CGRect(x: 0, y: 0, width: EditorCaret.width, height: EditorCaret.defaultHeight(for: font))
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let lineRange = CTLineGetStringRange(line)
            let localIndex = index - lineRange.location
            if localIndex >= 0 && localIndex <= lineRange.length {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                var lineOrigin: CGPoint = .zero
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 0), &lineOrigin)
                let caretHeight = ascent + descent + leading
                let xPos = CTLineGetOffsetForStringIndex(line, index, nil)
                let yPos = preferredSize.height - lineOrigin.y - ascent - leading
                return CGRect(x: xPos, y: yPos, width: EditorCaret.width, height: caretHeight)
            }
        }
        return CGRect(x: 0, y: 0, width: EditorCaret.width, height: EditorCaret.defaultHeight(for: font))
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let textFrame = textFrame else {
            return CGRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height)
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let lineRange = CTLineGetStringRange(line)
            let index = range.location
            if index >= 0 && index <= lineRange.length {
                let finalIndex = min(lineRange.location + lineRange.length, range.location + range.length)
                let xStart = CTLineGetOffsetForStringIndex(line, index, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, nil)
                var lineOrigin: CGPoint = .zero
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 0), &lineOrigin)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                let height = ascent + descent + leading
                let yPos = preferredSize.height - lineOrigin.y - ascent - leading
                return CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: height)
            }
        }
        return CGRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height)
    }

    func closestIndex(to point: CGPoint) -> Int? {
        guard let textFrame = textFrame else {
            return nil
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        var origins: [CGPoint] = Array(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(textFrame, CFRangeMake(0, lineCount), &origins)
        for lineIndex in 0 ..< lineCount {
            if point.y > origins[lineIndex].y {
                // This line is closest to the y-coordinate. Now we find the closest string index in the line.
                let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
                return CTLineGetStringIndexForPosition(line, point)
            }
        }
        // Fallback to max index.
        let range = CTFrameGetStringRange(textFrame)
        return range.length
    }

    func selectionRects(in range: NSRange) -> [EditorTextRendererSelectionRect] {
        guard let textFrame = textFrame else {
            return []
        }
        var selectionRects: [EditorTextRendererSelectionRect] = []
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let _lineRange = CTLineGetStringRange(line)
            let lineRange = NSRange(location: _lineRange.location, length: _lineRange.length)
            let selectionIntersection = range.intersection(lineRange)
            if let selectionIntersection = selectionIntersection {
                let xStart = floor(CTLineGetOffsetForStringIndex(line, selectionIntersection.location, nil))
                let xEnd = ceil(CTLineGetOffsetForStringIndex(line, selectionIntersection.location + selectionIntersection.length, nil))
                var lineOrigin: CGPoint = .zero
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 0), &lineOrigin)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                let height = ceil(ascent + descent + leading)
                let yPos = ceil(preferredSize.height - lineOrigin.y - ascent - leading)
                let rect = CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: height)
                let selectionRect = EditorTextRendererSelectionRect(rect: rect, range: selectionIntersection)
                selectionRects.append(selectionRect)
            }
        }
        return selectionRects
    }
}

private extension EditorTextRenderer {
    private func applyDefaultFont() {
        if let font = font, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            let range = CFRangeMake(0, length)
            apply(font, in: range)
        }
    }

    private func applyDefaultTextColor() {
        if let textColor = textColor, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            let range = CFRangeMake(0, length)
            apply(textColor, in: range)
        }
    }

    private func applyAttributes() {
        if let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            let entireRange = CFRangeMake(0, length)
            CFAttributedStringRemoveAttribute(attributedString, entireRange, kCTFontAttributeName)
            CFAttributedStringRemoveAttribute(attributedString, entireRange, kCTForegroundColorAttributeName)
            if let font = font {
                apply(font, in: entireRange)
            }
            if let textColor = textColor {
                apply(textColor, in: entireRange)
            }
            for attribute in attributes {
                apply(attribute)
            }
        }
    }

    private func apply(_ attributes: EditorTextRendererAttributes) {
        let range = CFRangeMake(attributes.range.location, attributes.range.length)
        if let textColor = attributes.textColor {
            apply(textColor, in: range)
        }
        if let font = attributes.font {
            apply(font, in: range)
        }
    }

    private func apply(_ font: UIFont, in range: CFRange) {
        if let attributedString = attributedString {
            CFAttributedStringSetAttribute(attributedString, range, kCTFontAttributeName, font)
        }
    }

    private func apply(_ textColor: UIColor, in range: CFRange) {
        if let attributedString = attributedString {
            CFAttributedStringSetAttribute(attributedString, range, kCTForegroundColorAttributeName, textColor)
        }
    }
}
