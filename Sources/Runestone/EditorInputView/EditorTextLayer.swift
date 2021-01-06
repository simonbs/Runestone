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

    private var textFrame: CTFrame?
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
    private var _framesetter: CTFramesetter?

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        ctx.translateBy(x: 0, y: bounds.size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity
        if let framesetter = framesetter {
            let path = CGMutablePath()
            path.addRect(bounds)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, ctx)
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

    private func updateFont() {
        if let font = font, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            CFAttributedStringSetAttribute(attributedString, CFRangeMake(0, length), kCTFontAttributeName, font)
        }
    }
}
