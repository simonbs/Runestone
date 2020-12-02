//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import UIKit

final class LineNumberLayoutManager: NSLayoutManager {
    override func processEditing(
        for textStorage: NSTextStorage,
        edited editMask: NSTextStorage.EditActions,
        range newCharRange: NSRange,
        changeInLength delta: Int,
        invalidatedRange invalidatedCharRange: NSRange) {
        super.processEditing(for: textStorage, edited: editMask, range: newCharRange, changeInLength: delta, invalidatedRange: invalidatedCharRange)
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
//        if let textStorage = textStorage {
//            enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, glyphRange, stop in
//                let characterNSRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
//                let characterRange = textStorage.string.convert(characterNSRange)
//                let paragraphRange = textStorage.string.paragraphRange(for: characterRange)
//                print(paragraphRange)
//            }
//        }
    }
}
