//
//  LineController.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import CoreText
import UIKit

final class LineController {
    let line: DocumentLineNode
    var lineFragmentHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineFragmentHeightMultiplier != oldValue {
                typesetter.lineFragmentHeightMultiplier = lineFragmentHeightMultiplier
                textInputProxy.lineFragmentHeightMultiplier = lineFragmentHeightMultiplier
            }
        }
    }
    var syntaxHighlighter: LineSyntaxHighlighter?
    var estimatedLineFragmentHeight: CGFloat = 15 {
        didSet {
            if estimatedLineFragmentHeight != oldValue {
                textInputProxy.estimatedLineFragmentHeight = estimatedLineFragmentHeight
            }
        }
    }
//    var invisibleCharacterConfiguration: InvisibleCharacterConfiguration {
//        get {
//            return renderer.invisibleCharacterConfiguration
//        }
//        set {
//            renderer.invisibleCharacterConfiguration = newValue
//        }
//    }
    private(set) var lineHeight: CGFloat = 0
    var tabWidth: CGFloat = 10
    var constrainingWidth: CGFloat? {
        get {
            return typesetter.constrainingWidth
        }
        set {
            typesetter.constrainingWidth = newValue
        }
    }
//    var lineViewFrame: CGRect = .zero {
//        didSet {
//            if lineViewFrame != oldValue {
//                lineView?.frame = lineViewFrame
//                renderer.lineViewFrame = lineViewFrame
//            }
//        }
//    }
//    var preferredSize: CGSize {
//        if let preferredSize = typesetter.preferredSize {
//            let lineBreakSymbolWidth = invisibleCharacterConfiguration.lineBreakSymbolSize.width
//            return CGSize(width: preferredSize.width + lineBreakSymbolWidth, height: preferredSize.height)
//        } else {
//            return CGSize(width: 0, height: estimatedLineHeight * lineHeightMultiplier)
//        }
//    }

    private let stringView: StringView
    private let typesetter: LineTypesetter
    private let textInputProxy = LineTextInputProxy()
    private var attributedString: NSMutableAttributedString?
    private var lineFragmentControllers: [LineFragmentID: LineFragmentController] = [:]
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true

    init(line: DocumentLineNode, stringView: StringView) {
        self.line = line
        self.stringView = stringView
        self.typesetter = LineTypesetter(lineID: line.id.rawValue)
        self.textInputProxy.estimatedLineFragmentHeight = estimatedLineFragmentHeight
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
        if needsDisplay {
            setNeedsDisplayOnLineFragmentViews()
        }
    }

    func didEndDisplaying() {
        syntaxHighlighter?.cancel()
    }

    func invalidate() {
        isTypesetterInvalid = true
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
    }

    func lineFragmentControllers(in rect: CGRect) -> [LineFragmentController] {
        var result: [LineFragmentController] = []
        let lineYPosition = line.yPosition
        for lineFragment in typesetter.lineFragments {
            let lineFragmentMinY = lineYPosition + lineFragment.yPosition
            let lineFragmentMaxY = lineFragmentMinY + lineFragment.scaledSize.height
            if lineFragmentMinY > rect.maxY {
                // We're past the bottom of the rect. There are no more line fragments within the rect.
                break
            } else if lineFragmentMaxY > rect.minY {
                let lineFragmentController = lineFragmentController(for: lineFragment)
                result.append(lineFragmentController)
            }
        }
        return result
    }
}

private extension LineController {
    private func updateStringIfNecessary() {
        if isStringInvalid {
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let string = stringView.substring(in: range)
            attributedString = NSMutableAttributedString(string: string)
            isStringInvalid = false
        }
    }

    private func updateDefaultAttributesIfNecessary() {
        if isDefaultAttributesInvalid {
            updateParagraphStyle()
            if let input = createLineSyntaxHighlightInput() {
                syntaxHighlighter?.setDefaultAttributes(on: input)
            }
            isDefaultAttributesInvalid = false
        }
    }

    private func updateParagraphStyle() {
        if let attributedString = attributedString {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = []
            paragraphStyle.defaultTabInterval = tabWidth
            let range = NSRange(location: 0, length: attributedString.length)
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }

    private func updateSyntaxHighlightingIfNecessary(async: Bool) {
        guard isSyntaxHighlightingInvalid else {
            return
        }
        guard let syntaxHighlighter = syntaxHighlighter else {
            return
        }
        guard syntaxHighlighter.canHighlight else {
            isSyntaxHighlightingInvalid = false
            return
        }
        guard let input = createLineSyntaxHighlightInput() else {
            isSyntaxHighlightingInvalid = false
            return
        }
        if async {
            syntaxHighlighter.cancel()
            syntaxHighlighter.syntaxHighlight(input) { [weak self] result in
                if case .success = result {
                    self?.typeset(input.attributedString)
                    self?.isSyntaxHighlightingInvalid = false
                    self?.isTypesetterInvalid = false
                }
            }
        } else {
            syntaxHighlighter.cancel()
            syntaxHighlighter.syntaxHighlight(input)
            typeset(input.attributedString)
            isSyntaxHighlightingInvalid = false
        }
    }

    private func updateTypesetterIfNecessary() {
        if isTypesetterInvalid {
            lineFragmentControllers.removeAll(keepingCapacity: true)
            if let attributedString = attributedString {
                typeset(attributedString)
            }
            isTypesetterInvalid = false
        }
    }

    private func createLineSyntaxHighlightInput() -> LineSyntaxHighlighterInput? {
        if let attributedString = attributedString {
            return LineSyntaxHighlighterInput(attributedString: attributedString, byteRange: line.data.byteRange)
        } else {
            return nil
        }
    }

    private func lineFragmentController(for lineFragment: LineFragment) -> LineFragmentController {
        if let lineFragmentController = lineFragmentControllers[lineFragment.id] {
            lineFragmentController.lineFragment = lineFragment
            return lineFragmentController
        } else {
            let lineFragmentController = LineFragmentController(lineFragment: lineFragment)
            lineFragmentController.delegate = self
            lineFragmentControllers[lineFragment.id] = lineFragmentController
            return lineFragmentController
        }
    }

    private func typeset(_ attributedString: NSAttributedString) {
        typesetter.typeset(attributedString)
        textInputProxy.lineFragments = typesetter.lineFragments
        cleanUpLineFragmentControllers()
        reapplyLineFragmentToLineFragmentControllers()
        setNeedsDisplayOnLineFragmentViews()
        updateLineHeight()
    }

    private func cleanUpLineFragmentControllers() {
        let lineFragmentIDs = Set(typesetter.lineFragments.map(\.id))
        let currentControllerIDs = Set(lineFragmentControllers.keys)
        let controllerIDsToRemove = currentControllerIDs.subtracting(lineFragmentIDs)
        for controllerID in controllerIDsToRemove {
            lineFragmentControllers.removeValue(forKey: controllerID)
        }
    }

    private func reapplyLineFragmentToLineFragmentControllers() {
        for (lineFragmentID, lineFragmentController) in lineFragmentControllers {
            if let lineFragment = typesetter.lineFragment(withID: lineFragmentID) {
                lineFragmentController.lineFragment = lineFragment
            }
        }
    }

    private func setNeedsDisplayOnLineFragmentViews() {
        for (_, lineFragmentController) in lineFragmentControllers {
            lineFragmentController.lineFragmentView?.setNeedsDisplay()
        }
    }

    private func updateLineHeight() {
        if typesetter.lineFragments.isEmpty {
            // This is an empty line. Possibly at the end of the file.
            lineHeight = estimatedLineFragmentHeight
        } else {
            lineHeight = typesetter.lineFragments.reduce(0) { $0 + $1.scaledSize.height }
        }
    }
}

// MARK: - UITextInput
extension LineController {
    func caretRect(atIndex index: Int) -> CGRect {
        return textInputProxy.caretRect(atIndex: index)
    }

    func selectionRects(in range: NSRange) -> [LineFragmentSelectionRect] {
        return textInputProxy.selectionRects(in: range)
    }

    func firstRect(for range: NSRange) -> CGRect {
        return textInputProxy.firstRect(for: range)
    }

    func closestIndex(to point: CGPoint) -> Int {
        return textInputProxy.closestIndex(to: point)
    }
}

// MARK: - LineFragmentControllerDelegate
extension LineController: LineFragmentControllerDelegate {
    func string(in controller: LineFragmentController) -> String? {
        let lineFragment = controller.lineFragment
        let cfRange = CTLineGetStringRange(lineFragment.line)
        let range = NSRange(location: line.location + cfRange.location, length: cfRange.length)
        return stringView.substring(in: range)
    }
}
