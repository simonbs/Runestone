//
//  LineController.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import CoreText
import Foundation

protocol LineControllerDelegate: AnyObject {
    func string(in lineController: LineController) -> String
}

final class LineController {
    weak var delegate: LineControllerDelegate?
    weak var lineView: LineView?
    let line: DocumentLineNode
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                typesetter.lineHeightMultiplier = lineHeightMultiplier
                textInputProxy.lineHeightMultiplier = lineHeightMultiplier
            }
        }
    }
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            if theme !== oldValue {
                textInputProxy.defaultLineHeight = theme.font.lineHeight
//                syntaxHighlighter.theme = theme
            }
        }
    }
    var invisibleCharacterConfiguration: InvisibleCharacterConfiguration {
        get {
            return renderer.invisibleCharacterConfiguration
        }
        set {
            renderer.invisibleCharacterConfiguration = newValue
        }
    }
    var constrainingWidth: CGFloat? {
        get {
            return typesetter.constrainingWidth
        }
        set {
            typesetter.constrainingWidth = newValue
        }
    }
    var lineViewFrame: CGRect = .zero {
        didSet {
            if lineViewFrame != oldValue {
                lineView?.frame = lineViewFrame
                renderer.lineViewFrame = lineViewFrame
            }
        }
    }
    var preferredSize: CGSize {
        if let preferredSize = typesetter.preferredSize {
            let lineBreakSymbolWidth = invisibleCharacterConfiguration.lineBreakSymbolSize.width
            return CGSize(width: preferredSize.width + lineBreakSymbolWidth, height: preferredSize.height)
        } else {
            return CGSize(width: 0, height: theme.font.lineHeight * lineHeightMultiplier)
        }
    }

//    private let languageMode: LanguageMode
    private let typesetter = LineTypesetter()
//    private let syntaxHighlighter: LineSyntaxHighlighter
    private let textInputProxy: LineTextInputProxy
    private let renderer: LineRenderer
    private var attributedString: NSMutableAttributedString?
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true

    init(line: DocumentLineNode) {
        self.line = line
//        self.syntaxHighlighter = LineSyntaxHighlighter(syntaxHighlighter: syntaxHighlighter, queue: syntaxHighlightQueue)
        self.textInputProxy = LineTextInputProxy(lineTypesetter: typesetter)
        self.textInputProxy.defaultLineHeight = theme.font.lineHeight
        self.renderer = LineRenderer(typesetter: typesetter)
    }

    func typeset() {
        isStringInvalid = true
        isDefaultAttributesInvalid = true
        isTypesetterInvalid = true
        updateStringIfNecessary()
        updateDefaultAttributesIfNecessary()
        updateTypesetterIfNecessary()
    }

    func syntaxHighlight() {
        // We need to invalidate the typesetter when invalidating the syntax highlighting because
        // the CTTypesetter needs to generate new instances of CTLine with the new attributes.
        isTypesetterInvalid = true
        isSyntaxHighlightingInvalid = true
        updateSyntaxHighlightingIfNecessary(async: false)
    }

    func willDisplay() {
        let needsDisplay = isStringInvalid || isTypesetterInvalid || isDefaultAttributesInvalid || isSyntaxHighlightingInvalid
        updateStringIfNecessary()
        updateDefaultAttributesIfNecessary()
        updateTypesetterIfNecessary()
        updateSyntaxHighlightingIfNecessary(async: true)
        lineView?.delegate = self
        lineView?.frame = lineViewFrame
        if needsDisplay {
            lineView?.setNeedsDisplay()
        }
    }

    func didEndDisplaying() {
        lineView?.delegate = nil
        lineView = nil
//        syntaxHighlighter.cancelHighlightOperation()
    }

    func invalidate() {
        isTypesetterInvalid = true
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
    }
}

private extension LineController {
    private func updateStringIfNecessary() {
        if isStringInvalid {
            let string = delegate!.string(in: self)
            attributedString = NSMutableAttributedString(string: string)
            isStringInvalid = false
        }
    }

    private func updateDefaultAttributesIfNecessary() {
        if isDefaultAttributesInvalid {
//            if let attributedString = attributedString {
//                syntaxHighlighter.setDefaultAttributes(on: attributedString)
//            }
//            isDefaultAttributesInvalid = false
        }
    }

    private func updateSyntaxHighlightingIfNecessary(async: Bool) {
//        guard isSyntaxHighlightingInvalid else {
//            return
//        }
//        guard syntaxHighlighter.canHighlight else {
//            isSyntaxHighlightingInvalid = false
//            return
//        }
//        guard let attributedString = attributedString else {
//            isSyntaxHighlightingInvalid = false
//            return
//        }
//        if async {
//            syntaxHighlighter.syntaxHighlight(attributedString, documentByteRange: line.data.byteRange) { [weak self] result in
//                if case .success = result {
//                    self?.typesetter.typeset(attributedString)
//                    self?.lineView?.setNeedsDisplay()
//                    self?.isSyntaxHighlightingInvalid = false
//                    self?.isTypesetterInvalid = false
//                }
//            }
//        } else {
//            syntaxHighlighter.syntaxHighlight(attributedString, documentByteRange: line.data.byteRange)
//            isSyntaxHighlightingInvalid = false
//        }
    }

    private func updateTypesetterIfNecessary() {
        if isTypesetterInvalid {
            if let attributedString = attributedString {
                typesetter.typeset(attributedString)
            }
            isTypesetterInvalid = false
        }
    }
}

// MARK: - UITextInput
extension LineController {
    func caretRect(atIndex index: Int) -> CGRect {
        return textInputProxy.caretRect(atIndex: index)
    }

    func selectionRects(in range: NSRange) -> [TypesetLineSelectionRect] {
        return textInputProxy.selectionRects(in: range)
    }

    func firstRect(for range: NSRange) -> CGRect {
        return textInputProxy.firstRect(for: range)
    }

    func closestIndex(to point: CGPoint) -> Int {
        return textInputProxy.closestIndex(to: point)
    }
}

// MARK: - LineViewDelegate
extension LineController: LineViewDelegate {
    func lineView(_ lineView: LineView, shouldDrawTo context: CGContext) {
        if let string = attributedString?.string {
            renderer.draw(string, to: context)
        }
    }
}
