//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

protocol EditorInvisibleCharactersControllerDelegate: AnyObject {
    func editorInvisibleCharactersController(_ controller: EditorInvisibleCharactersController, substringIn range: NSRange) -> String
}

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

    weak var delegate: EditorInvisibleCharactersControllerDelegate?
    weak var layoutManager: NSLayoutManager?
    var showTabs = false
    var showSpaces = false
    var showLineBreaks = false
    var textContainerInset: UIEdgeInsets = .zero
    var font: UIFont?

    private var drawInvisibleCharacters: Bool {
        return showTabs || showSpaces || showLineBreaks
    }
    private var currentLayoutManager: NSLayoutManager {
        if let layoutManager = layoutManager {
            return layoutManager
        } else {
            fatalError("Layout manager unavailable.")
        }
    }
    private var currentDelegate: EditorInvisibleCharactersControllerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Delegaete unvailable")
        }
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
        var actualGlyphRange = NSRange(location: 0, length: 0)
        currentLayoutManager.characterRange(forGlyphRange: NSMakeRange(glyphLocation, 1), actualGlyphRange: &actualGlyphRange)
        let characterRange = currentLayoutManager.characterRange(forGlyphRange: actualGlyphRange, actualGlyphRange: nil)
        let character = currentDelegate.editorInvisibleCharactersController(self, substringIn: characterRange)
        if showTabs && character == Symbol.tab {
            draw(BackgroundSymbol.tab, at: .minX, inGlyphRange: actualGlyphRange, of: lineFragment.textContainer)
        } else if showSpaces && character == Symbol.space {
            draw(BackgroundSymbol.space, at: .minX, inGlyphRange: actualGlyphRange, of: lineFragment.textContainer)
        } else if showLineBreaks && character == Symbol.lineFeed {
            var bounds = lineFragment.usedRect
            bounds.origin.x = lineFragment.usedRect.minX + lineFragment.textContainer.lineFragmentPadding + textContainerInset.left
            bounds.origin.y = lineFragment.usedRect.minY + textContainerInset.top
            draw(BackgroundSymbol.newLine, at: .maxX, in: bounds)
        }
    }

    private func draw(_ symbol: String, at position: HorizontalSymbolPosition, inGlyphRange glyphRange: NSRange, of textContainer: NSTextContainer) {
        let bounds = currentLayoutManager
            .boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
        draw(symbol, at: position, in: bounds)
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
