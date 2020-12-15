//
//  EditorLayoutManager.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import UIKit

protocol EditorLayoutManagerDelegate: AnyObject {
    func editorLayoutManagerShouldEnumerateLineFragments(_ layoutManager: EditorLayoutManager) -> Bool
    func editorLayoutManagerWillEnumerateLineFragments(_ layoutManager: EditorLayoutManager)
    func editorLayoutManagerDidEnumerateLineFragments(_ layoutManager: EditorLayoutManager)
    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didEnumerate lineFragment: EditorLineFragment)
}

final class EditorLayoutManager: NSLayoutManager {
    var font: UIFont?
    weak var editorDelegate: EditorLayoutManagerDelegate?

    override func glyphRange(forBoundingRect bounds: CGRect, in container: NSTextContainer) -> NSRange {
        var range = super.glyphRange(forBoundingRect: bounds, in: container)
        if let textStorage = textStorage, range.length == 0, bounds.intersects(extraLineFragmentRect), textStorage.length > 0 {
            // Setting the range to the last character in the textStorage when dealing with the
            // extra line ensures that the layout manager has the correct size when drawing its
            // background. Thanks for sharing this snippet Alexsander Akers (http://twitter.com/a2)
            range = NSRange(location: textStorage.length - 1, length: 1)
        }
        return range
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let editorDelegate = editorDelegate, editorDelegate.editorLayoutManagerShouldEnumerateLineFragments(self) else {
            return
        }
        editorDelegate.editorLayoutManagerWillEnumerateLineFragments(self)
        enumerateLineFragments(forGlyphRange: glyphsToShow) { [weak self] rect, usedRect, textContainer, glyphRange, stop in
            if let self = self {
                let lineFragment = EditorLineFragment(rect: rect, usedRect: usedRect, textContainer: textContainer, glyphRange: glyphRange)
                self.editorDelegate?.editorLayoutManager(self, didEnumerate: lineFragment)
            }
        }
        editorDelegate.editorLayoutManagerDidEnumerateLineFragments(self)
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
