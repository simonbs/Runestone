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
}
