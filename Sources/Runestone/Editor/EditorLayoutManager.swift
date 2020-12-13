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
    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didEnumerate lineFragment: EditorLineFragment)
    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didFinishEnumeratingLinesIn glyphRange: NSRange, outOf numberOfGlyphs: Int)
}

final class EditorLayoutManager: NSLayoutManager {
    weak var editorDelegate: EditorLayoutManagerDelegate?

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
        editorDelegate.editorLayoutManager(self, didFinishEnumeratingLinesIn: glyphsToShow, outOf: numberOfGlyphs)
    }
}
