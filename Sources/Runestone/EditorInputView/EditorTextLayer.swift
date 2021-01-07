//
//  File.swift
//  
//
//  Created by Simon Støvring on 06/01/2021.
//

import UIKit

final class EditorTextLayer: CALayer {
    var font: UIFont? {
        didSet {
            if font != oldValue {
                updateFont()
            }
        }
    }
    override var bounds: CGRect {
        didSet {
            if bounds != oldValue {
                _textFrame = nil
            }
        }
    }

    private var cachedPreferredSize: CGSize?
    private var cachedConstrainingWidth: CGFloat?
    private var attributedString: CFMutableAttributedString?
    private var framesetter: CTFramesetter? {
        set {
            _framesetter = newValue
        }
        get {
            if let framesetter = _framesetter {
                return framesetter
            } else if let attributedString = attributedString {
                _framesetter = CTFramesetterCreateWithAttributedString(attributedString)
                return _framesetter
            } else {
                return nil
            }
        }
    }
    private var textFrame: CTFrame? {
        if let frame = _textFrame {
            return frame
        } else if let framesetter = framesetter {
            let path = CGMutablePath()
            path.addRect(bounds)
            _textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            return _textFrame
        } else {
            return nil
        }
    }
    private var _framesetter: CTFramesetter?
    private var _textFrame: CTFrame?

    override init() {
        super.init()
        isGeometryFlipped = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        if let textFrame = textFrame {
            CTFrameDraw(textFrame, ctx)
        }
    }

    func preferredSize(constrainedToWidth width: CGFloat) -> CGSize {
        if width == cachedConstrainingWidth, let cachedPreferredSize = cachedPreferredSize {
            return cachedPreferredSize
        } else if let framesetter = framesetter {
            let constrainingSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let preferedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constrainingSize, nil)
            cachedPreferredSize = preferedSize
            cachedConstrainingWidth = width
            return preferedSize
        } else {
            return .zero
        }
    }

    func setString(_ string: NSString) {
        cachedPreferredSize = nil
        cachedConstrainingWidth = nil
        framesetter = nil
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.length)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string)
            updateFont()
        }
    }

    func caretRect(aIndex index: Int) -> CGRect? {
        guard let textFrame = textFrame else {
            return nil
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let lineRange = CTLineGetStringRange(line)
            if index >= 0 && index <= lineRange.location + lineRange.length {
                var origin: CGPoint = .zero
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 1), &origin)
                let height = ascent + descent
                let xPos = CTLineGetOffsetForStringIndex(line, index, nil)
                let yPos = origin.y - descent
                let flippedYPos = bounds.height - (yPos + height)
                return CGRect(x: xPos, y: flippedYPos, width: 3, height: height)
            }
        }
        return nil
    }

    func firstRect(for range: NSRange) -> CGRect? {
        guard let textFrame = textFrame else {
            return nil
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
                var origin: CGPoint = .zero
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 0), &origin)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                let height = ascent + descent
                let yPos = origin.y - descent
                let flippedYPos = bounds.height - (yPos + height)
                return CGRect(x: xStart, y: flippedYPos, width: xEnd - xStart, height: height)
            }
        }
        return nil
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
}

private extension EditorTextLayer {
    private func updateFont() {
        if let font = font, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            CFAttributedStringSetAttribute(attributedString, CFRangeMake(0, length), kCTFontAttributeName, font)
        }
    }
}
