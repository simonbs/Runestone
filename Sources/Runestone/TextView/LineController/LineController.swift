//
//  LineController.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import CoreText
import UIKit

struct LineFragmentNodeID: RedBlackTreeNodeID {
    let id = UUID()
}

typealias LineFragmentTree = RedBlackTree<LineFragmentNodeID, Int, Void>
typealias LineFragmentNode = RedBlackTreeNode<LineFragmentNodeID, Int, Void>

protocol LineControllerDelegate: AnyObject {
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController)
}

final class LineController {
    weak var delegate: LineControllerDelegate?
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
    var tabWidth: CGFloat = 10
    var constrainingWidth: CGFloat {
        get {
            return typesetter.constrainingWidth
        }
        set {
            typesetter.constrainingWidth = newValue
        }
    }
    var lineWidth: CGFloat {
        return ceil(typesetter.maximumLineWidth)
    }
    var lineHeight: CGFloat {
        if let lineHeight = _lineHeight {
            return lineHeight
        } else if typesetter.lineFragments.isEmpty {
            let lineHeight = estimatedLineFragmentHeight * lineFragmentHeightMultiplier
            _lineHeight = lineHeight
            return lineHeight
        } else {
            let lineHeight = typesetter.lineFragments.reduce(0) { $0 + $1.scaledSize.height }
            _lineHeight = lineHeight
            return lineHeight
        }
    }
    var numberOfLineFragments: Int {
        return typesetter.lineFragments.count
    }

    private let stringView: StringView
    private let typesetter: LineTypesetter
    private let textInputProxy = LineTextInputProxy()
    private var attributedString: NSMutableAttributedString?
    private var lineFragmentControllers: [LineFragmentID: LineFragmentController] = [:]
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true
    private var _lineHeight: CGFloat?
    private var lineFragmentTree = LineFragmentTree(minimumValue: 0, rootValue: 0)

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
        _lineHeight = nil
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
        _lineHeight = nil
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
    
    func lineFragmentNode(containingCharacterAt location: Int) -> LineFragmentNode {
        return lineFragmentTree.node(containingLocation: location)
    }

    func lineFragmentNode(atIndex index: Int) -> LineFragmentNode {
        return lineFragmentTree.node(atIndex: index)
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
                if case .success = result, let self = self {
                    let oldWidth = self.lineWidth
                    self.typeset(input.attributedString)
                    self.isSyntaxHighlightingInvalid = false
                    if abs(self.lineWidth - oldWidth) > CGFloat.ulpOfOne {
                        self.delegate?.lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(self)
                    }
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
        _lineHeight = nil
        typesetter.typeset(attributedString)
        textInputProxy.lineFragments = typesetter.lineFragments
        cleanUpLineFragmentControllers()
        reapplyLineFragmentToLineFragmentControllers()
        setNeedsDisplayOnLineFragmentViews()
        rebuildLineFragmentTree()
        isTypesetterInvalid = false
    }

    private func rebuildLineFragmentTree() {
        lineFragmentTree.reset(rootValue: 0)
        if !typesetter.lineFragments.isEmpty {
            let nodes: [LineFragmentNode] = typesetter.lineFragments.map { lineFragment in
                let range = CTLineGetStringRange(lineFragment.line)
                return LineFragmentNode(tree: lineFragmentTree, value: range.length)
            }
            lineFragmentTree.rebuild(from: nodes)
        } else {
            let node = LineFragmentNode(tree: lineFragmentTree, value: 0)
            lineFragmentTree.rebuild(from: [node])
        }
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
