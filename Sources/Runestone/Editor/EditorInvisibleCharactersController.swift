//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit
import RunestoneTextStorage

final class EditorInvisibleCharactersController {
    private enum BackgroundSymbol {
        static let newLine = "\u{00ac}"
        static let tab = "\u{25b8}"
        static let space = "\u{00b7}"
    }

    private enum HorizontalSymbolPosition {
        case minX
        case maxX
    }

    weak var layoutManager: NSLayoutManager?
    var showTabs = false
    var showSpaces = false
    var showLineBreaks = false
    var textContainerInset: UIEdgeInsets = .zero
    var font: UIFont?

    private weak var textStorage: EditorTextStorage?
    private var drawInvisibleCharacters: Bool {
        return showTabs || showSpaces || showLineBreaks
    }

    func drawInvisibleCharacters(in lineFragment: EditorLineFragment) {
        if drawInvisibleCharacters {
            for i in 0 ..< lineFragment.glyphRange.length {
                let glyphLocation = lineFragment.glyphRange.location + i
                drawInvisibleCharacter(forGlyphAt: glyphLocation, in: lineFragment)
            }
        }
    }
}

private extension EditorInvisibleCharactersController {
    private func drawInvisibleCharacter(forGlyphAt glyphLocation: Int, in lineFragment: EditorLineFragment) {
        guard let layoutManager = layoutManager else {
            return
        }
        var actualGlyphRange = NSRange(location: 0, length: 0)
        layoutManager.characterRange(forGlyphRange: NSMakeRange(glyphLocation, 1), actualGlyphRange: &actualGlyphRange)
        let characterRange = layoutManager.characterRange(forGlyphRange: actualGlyphRange, actualGlyphRange: nil)
        guard let substring = textStorage?.substring(in: characterRange) else {
            return
        }
        if showTabs && substring == Symbol.tab {
            draw(BackgroundSymbol.tab, at: .minX, inGlyphRange: actualGlyphRange, of: lineFragment.textContainer)
        } else if showSpaces && substring == Symbol.space {
            draw(BackgroundSymbol.space, at: .minX, inGlyphRange: actualGlyphRange, of: lineFragment.textContainer)
        } else if showLineBreaks && substring == Symbol.lineFeed {
            var bounds = lineFragment.usedRect
            bounds.origin.x = lineFragment.usedRect.minX + lineFragment.textContainer.lineFragmentPadding + textContainerInset.left
            bounds.origin.y = lineFragment.usedRect.minY + textContainerInset.top
            draw(BackgroundSymbol.newLine, at: .maxX, in: bounds)
        }
    }

    private func draw(_ symbol: String, at position: HorizontalSymbolPosition, inGlyphRange glyphRange: NSRange, of textContainer: NSTextContainer) {
        if let layoutManager = layoutManager {
            let bounds = layoutManager
                .boundingRect(forGlyphRange: glyphRange, in: textContainer)
                .offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
            draw(symbol, at: position, in: bounds)
        }
    }

    private func draw(_ symbol: String, at position: HorizontalSymbolPosition, in bounds: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.secondaryLabel, .font: font as Any]
        let size = symbol.size(withAttributes: attrs)
        let xPosition: CGFloat
        switch position {
        case .minX: xPosition = bounds.minX
        case .maxX: xPosition = bounds.maxX - size.width
        }
        let rect = CGRect(x: xPosition, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }
}
