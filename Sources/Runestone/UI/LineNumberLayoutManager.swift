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
        let context = UIGraphicsGetCurrentContext()
        if let textStorage = textStorage {
            let nsString = textStorage.string as NSString
            enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, glyphRange, stop in
                for i in 0 ..< glyphRange.length {
                    let singleGlyphRange = self.characterRange(forGlyphRange: NSMakeRange(glyphRange.location + i, 1), actualGlyphRange: nil)
                    let characterNSRange = self.characterRange(forGlyphRange: singleGlyphRange, actualGlyphRange: nil)
                    let character = nsString.substring(with: characterNSRange)
                    if character == "\n" {
                        let previousSingleGlyphRange = self.characterRange(forGlyphRange: NSMakeRange(singleGlyphRange.location - 1, 1), actualGlyphRange: nil)
                        let bounds = self.boundingRect(forGlyphRange: previousSingleGlyphRange, in: textContainer)
                        let rect = CGRect(x: bounds.maxX + 5, y: bounds.midY, width: 10, height: bounds.height)
                        let sym = "↵"
                        (sym as NSString).draw(in: rect, withAttributes: [.foregroundColor: UIColor.secondaryLabel])
                    } else if character == "\t" {
                        let bounds = self.boundingRect(forGlyphRange: singleGlyphRange, in: textContainer)
                        let rect = CGRect(x: bounds.minX, y: bounds.midY, width: 10, height: bounds.height)
                        let sym = "⇥"
                        (sym as NSString).draw(in: rect, withAttributes: [.foregroundColor: UIColor.secondaryLabel])
                    }
                }
            }
        }
    }
}
