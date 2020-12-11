//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import UIKit

final class LineNumberLayoutManager: NSLayoutManager {
    private enum BackgroundSymbol {
        static let newLine = "\u{00ac}"
        static let tab = "\u{25b8}"
        static let space = "\u{00b7}"
    }

    private enum HorizontalSymbolPosition {
        case minX
        case maxX
    }

    var textContainerInset: UIEdgeInsets = .zero
    var font: UIFont? = .systemFont(ofSize: 14)

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
        if let textStorage = textStorage {
            let nsString = textStorage.string as NSString
            enumerateLineFragments(forGlyphRange: glyphsToShow) { [weak self] rect, usedRect, textContainer, glyphRange, stop in
                guard let self = self else {
                    return
                }
                for i in 0 ..< glyphRange.length {
                    var actualGlyphRange = NSRange(location: 0, length: 0)
                    self.characterRange(forGlyphRange: NSMakeRange(glyphRange.location + i, 1), actualGlyphRange: &actualGlyphRange)
                    let characterNSRange = self.characterRange(forGlyphRange: actualGlyphRange, actualGlyphRange: nil)
                    let character = nsString.substring(with: characterNSRange)
                    if character == Symbol.space {
                        self.draw(BackgroundSymbol.space, at: .minX, inGlyphRange: actualGlyphRange, of: textContainer)
                    } else if character == Symbol.tab {
                        self.draw(BackgroundSymbol.tab, at: .minX, inGlyphRange: actualGlyphRange, of: textContainer)
                    } else if character == Symbol.lineFeed {
                        let previousCharacterRange = NSRange(location: actualGlyphRange.location - 1, length: 1)
                        self.draw(BackgroundSymbol.newLine, at: .maxX, inGlyphRange: previousCharacterRange, of: textContainer)
                    }
                }
            }
        }
    }
}

private extension LineNumberLayoutManager {
    private func draw(_ symbol: String, at position: HorizontalSymbolPosition, inGlyphRange glyphRange: NSRange, of textContainer: NSTextContainer) {
        let bounds = boundingRect(forGlyphRange: glyphRange, in: textContainer).offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
        draw(symbol, at: position, in: bounds)
    }

    private func draw(_ symbol: String, at position: HorizontalSymbolPosition, in bounds: CGRect) {
        let xPosition: CGFloat
        switch position {
        case .minX: xPosition = bounds.minX
        case .maxX: xPosition = bounds.maxX
        }
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.secondaryLabel, .font: font as Any]
        let size = symbol.size(withAttributes: attrs)
        let rect = CGRect(x: xPosition, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }
}
