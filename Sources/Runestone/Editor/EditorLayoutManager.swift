//
//  EditorLayoutManager.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import UIKit

protocol EditorLayoutManagerDelegate: AnyObject {
    func editorLayoutManagerShouldEnumerateLineFragments(_ layoutManager: EditorLayoutManager) -> Bool
    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didEnumerate lineFragment: EditorLineFragment)
}

final class EditorLayoutManager: NSLayoutManager {
    var font: UIFont?
    weak var editorDelegate: EditorLayoutManagerDelegate?

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let editorDelegate = editorDelegate, editorDelegate.editorLayoutManagerShouldEnumerateLineFragments(self) else {
            return
        }
        enumerateLineFragments(forGlyphRange: glyphsToShow) { [weak self] rect, usedRect, textContainer, glyphRange, stop in
            if let self = self {
                let lineFragment = EditorLineFragment(rect: rect, usedRect: usedRect, textContainer: textContainer, glyphRange: glyphRange)
                self.editorDelegate?.editorLayoutManager(self, didEnumerate: lineFragment)
            }
        }
    }

    override func setExtraLineFragmentRect(_ fragmentRect: CGRect, usedRect: CGRect, textContainer container: NSTextContainer) {
        if let font = font {
            var modifiedFragmentRect = fragmentRect
            modifiedFragmentRect.size.height = font.lineHeight
            super.setExtraLineFragmentRect(modifiedFragmentRect, usedRect: usedRect, textContainer: container)
        } else {
            super.setExtraLineFragmentRect(fragmentRect, usedRect: usedRect, textContainer: container)
        }
    }

    override func setLineFragmentRect(_ fragmentRect: CGRect, forGlyphRange glyphRange: NSRange, usedRect: CGRect) {
        let substring = textStorage?.attributedSubstring(from: glyphRange).string
        if let font = font, substring == Symbol.lineFeed {
            var modifiedFragmentRect = fragmentRect
            modifiedFragmentRect.size.height = font.lineHeight
            var modifiedUsedRect = usedRect
            modifiedUsedRect.size.height = font.lineHeight
            super.setLineFragmentRect(modifiedFragmentRect, forGlyphRange: glyphRange, usedRect: modifiedUsedRect)
        } else {
            super.setLineFragmentRect(fragmentRect, forGlyphRange: glyphRange, usedRect: usedRect)
        }
    }
}
