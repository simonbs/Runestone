//
//  File.swift
//  
//
//  Created by Simon Støvring on 06/01/2021.
//

import UIKit

final class EditorTextLayer {
    var font: UIFont? {
        didSet {
            if font != oldValue {
                updateFont()
            }
        }
    }
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
    var origin: CGPoint = .zero {
        didSet {
            if origin != oldValue {
                _textFrame = nil
            }
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
            path.addRect(CGRect(x: origin.x, y: origin.y, width: preferredSize.width, height: preferredSize.height))
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

    func setString(_ string: NSString) {
        _preferredSize = nil
        _framesetter = nil
        _textFrame = nil
        isEmpty = string.length == 0
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.length)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string)
            updateFont()
        }
    }

    func draw(in context: CGContext) {
        if let textFrame = textFrame {
            CTFrameDraw(textFrame, context)
            context.saveGState()
            let rect = CGRect(x: origin.x, y: origin.y, width: preferredSize.width, height: preferredSize.height)
            context.setLineWidth(1)
            context.setStrokeColor(UIColor.red.cgColor)
            context.stroke(rect)
            context.restoreGState()
        }
    }

    func caretRect(atIndex index: Int) -> EditorTextLayerRect {
        let caretWidth: CGFloat = 3
        guard let textFrame = textFrame else {
            let rect = CGRect(x: 0, y: 0, width: caretWidth, height: font?.lineHeight ?? 0)
            return EditorTextLayerRect(rect)
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
                let rect = CGRect(x: xPos, y: yPos, width: caretWidth, height: caretHeight)
                return EditorTextLayerRect(rect)
            }
        }
        let rect = CGRect(x: 0, y: 0, width: caretWidth, height: font?.lineHeight ?? 0)
        return EditorTextLayerRect(rect)
    }

    func firstRect(for range: NSRange) -> EditorTextLayerRect {
        guard let textFrame = textFrame else {
            let rect = CGRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height)
            return EditorTextLayerRect(rect)
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
                let rect = CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: height)
                return EditorTextLayerRect(rect)
            }
        }
        let rect = CGRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height)
        return EditorTextLayerRect(rect)
    }

    func closestIndex(to point: EditorTextLayerPoint) -> Int? {
        guard let textFrame = textFrame else {
            return nil
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        var origins: [CGPoint] = Array(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(textFrame, CFRangeMake(0, lineCount), &origins)
//        print(point)
        for lineIndex in 0 ..< lineCount {
//            print("  \(origins[lineIndex].y)")
            if preferredSize.height - point.y > origins[lineIndex].y {
                // This line is closest to the y-coordinate. Now we find the closest string index in the line.
                let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
                return CTLineGetStringIndexForPosition(line, point.point)
            }
        }
        // Fallback to max index.
        let range = CTFrameGetStringRange(textFrame)
        return range.length
    }
}

private extension EditorTextLayer {
    private func updateFont() {
        if let font = font, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            CFAttributedStringSetAttribute(attributedString, CFRangeMake(0, length), kCTFontAttributeName, font)
        }
    }
}
