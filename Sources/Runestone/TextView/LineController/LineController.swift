//
//  LineController.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import CoreText
import UIKit

typealias LineFragmentTree = RedBlackTree<LineFragmentNodeID, Int, LineFragmentNodeData>

protocol LineControllerDelegate: AnyObject {
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController)
}

protocol LineControllerAttributedStringObserver: AnyObject {
    func lineControllerDidUpdateAttributedString(_ lineController: LineController)
}

final class LineController {
    private final class WeakObserver {
        private(set) weak var observer: LineControllerAttributedStringObserver?

        init(_ observer: LineControllerAttributedStringObserver) {
            self.observer = observer
        }
    }

    private enum StringDisplayPreparationAmount {
        case inRect(CGRect)
        case toLocation(Int)
    }

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
            let knownLineFragmentHeight = typesetter.lineFragments.reduce(0) { $0 + $1.scaledSize.height }
            let remainingNumberOfLineFragments = typesetter.bestGuessNumberOfLineFragments - typesetter.lineFragments.count
            let lineFragmentHeight = estimatedLineFragmentHeight * lineFragmentHeightMultiplier
            let remainingLineFragmentHeight = CGFloat(remainingNumberOfLineFragments) * lineFragmentHeight
            let lineHeight = knownLineFragmentHeight + remainingLineFragmentHeight
            _lineHeight = lineHeight
            return lineHeight
        }
    }
    var numberOfLineFragments: Int {
        return typesetter.lineFragments.count
    }
    var isFinishedTypesetting: Bool {
        return typesetter.isFinishedTypesetting
    }
    private(set) var attributedString: NSMutableAttributedString? {
        didSet {
            if attributedString != oldValue {
                invokeEachAttributedStringObserver { $0.lineControllerDidUpdateAttributedString(self) }
            }
        }
    }

    private let stringView: StringView
    private let typesetter: LineTypesetter
    private let textInputProxy = LineTextInputProxy()
    private var lineFragmentControllers: [LineFragmentID: LineFragmentController] = [:]
    private var isLineFragmentCacheInvalid = true
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true
    private var _lineHeight: CGFloat?
    private var lineFragmentTree: LineFragmentTree
    private var attributedStringObservers: [ObjectIdentifier: WeakObserver] = [:]

    init(line: DocumentLineNode, stringView: StringView) {
        self.line = line
        self.stringView = stringView
        self.typesetter = LineTypesetter(lineID: line.id.rawValue)
        self.textInputProxy.estimatedLineFragmentHeight = estimatedLineFragmentHeight
        let rootLineFragmentNodeData = LineFragmentNodeData(lineFragment: nil)
        self.lineFragmentTree = LineFragmentTree(minimumValue: 0, rootValue: 0, rootData: rootLineFragmentNodeData)
    }

    deinit {
        attributedStringObservers = [:]
    }

    func prepareToDisplayString(in rect: CGRect, syntaxHighlightAsynchronously: Bool) {
        prepareToDisplayString(.inRect(rect), syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
    }

    func prepareToDisplayString(toLocation location: Int, syntaxHighlightAsynchronously: Bool) {
        prepareToDisplayString(.toLocation(location), syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
    }

    func cancelSyntaxHighlighting() {
        syntaxHighlighter?.cancel()
    }

    func invalidateEverything() {
        isLineFragmentCacheInvalid = true
        isStringInvalid = true
        isTypesetterInvalid = true
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
        _lineHeight = nil
    }

    func invalidateSyntaxHighlighting() {
        isTypesetterInvalid = true
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
        _lineHeight = nil
    }

    func lineFragmentControllers(in rect: CGRect) -> [LineFragmentController] {
        let lineYPosition = line.yPosition
        let localMinY = rect.minY - lineYPosition
        let localMaxY = rect.maxY - lineYPosition
        let query = LineFragmentFrameQuery(range: localMinY ... localMaxY)
        return lineFragmentControllers(matching: query)
    }
    
    func lineFragmentNode(containingCharacterAt location: Int) -> LineFragmentNode {
        return lineFragmentTree.node(containingLocation: location)
    }

    func lineFragmentNode(atIndex index: Int) -> LineFragmentNode {
        return lineFragmentTree.node(atIndex: index)
    }

    func setNeedsDisplayOnLineFragmentViews() {
        for (_, lineFragmentController) in lineFragmentControllers {
            lineFragmentController.lineFragmentView?.setNeedsDisplay()
        }
    }

    func addObserver(_ observer: LineControllerAttributedStringObserver) {
        let identifier = ObjectIdentifier(observer)
        attributedStringObservers[identifier] = WeakObserver(observer)
        cleanUpAttributedStringObservers()
    }

    func removeObserver(_ observer: LineControllerAttributedStringObserver) {
        let identifier = ObjectIdentifier(observer)
        attributedStringObservers.removeValue(forKey: identifier)
        cleanUpAttributedStringObservers()
    }
}

private extension LineController {
    private func prepareToDisplayString(_ preparationAmount: StringDisplayPreparationAmount, syntaxHighlightAsynchronously: Bool) {
        prepareString(syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
        let newLineFragments: [LineFragment]
        switch preparationAmount {
        case .inRect(let rect):
            newLineFragments = typesetter.typesetLineFragments(in: rect)
        case .toLocation(let location):
            // When typesetting to a location we'll typeset an additional line fragment to ensure that we can display the text surrounding that location.
            newLineFragments = typesetter.typesetLineFragments(toLocation: location, additionalLineFragmentCount: 1)
        }
        updateLineHeight(for: newLineFragments)
        textInputProxy.lineFragments = typesetter.lineFragments
    }

    private func prepareString(syntaxHighlightAsynchronously: Bool) {
        syntaxHighlighter?.cancel()
        clearLineFragmentControllersIfNecessary()
        updateStringIfNecessary()
        updateDefaultAttributesIfNecessary()
        updateSyntaxHighlightingIfNecessary(async: syntaxHighlightAsynchronously)
        updateTypesetterIfNecessary()
    }

    private func clearLineFragmentControllersIfNecessary() {
        if isLineFragmentCacheInvalid {
            lineFragmentControllers.removeAll(keepingCapacity: true)
            isLineFragmentCacheInvalid = false
        }
    }

    private func updateStringIfNecessary() {
        if isStringInvalid {
            let range = NSRange(location: line.location, length: line.data.totalLength)
            if let string = stringView.substring(in: range) {
                attributedString = NSMutableAttributedString(string: string)
            } else {
                attributedString = nil
            }
            isStringInvalid = false
            isDefaultAttributesInvalid = true
            isSyntaxHighlightingInvalid = true
            isTypesetterInvalid = true
        }
    }

    private func updateDefaultAttributesIfNecessary() {
        if isDefaultAttributesInvalid {
            updateParagraphStyle()
            if let input = createLineSyntaxHighlightInput() {
                syntaxHighlighter?.setDefaultAttributes(on: input.attributedString)
            }
            isDefaultAttributesInvalid = false
            isSyntaxHighlightingInvalid = true
            isTypesetterInvalid = true
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

    private func updateTypesetterIfNecessary() {
        if isTypesetterInvalid {
            lineFragmentTree.reset(rootValue: 0, rootData: LineFragmentNodeData(lineFragment: nil))
            typesetter.reset()
            if let attributedString = attributedString {
                typesetter.prepareToTypeset(attributedString)
            }
            isTypesetterInvalid = false
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
            syntaxHighlighter.syntaxHighlight(input) { [weak self] result in
                if case .success = result, let self = self {
                    let oldWidth = self.lineWidth
                    self.isSyntaxHighlightingInvalid = false
                    self.isTypesetterInvalid = true
                    self.redisplayLineFragments()
                    self.invokeEachAttributedStringObserver { $0.lineControllerDidUpdateAttributedString(self) }
                    if abs(self.lineWidth - oldWidth) > CGFloat.ulpOfOne {
                        self.delegate?.lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(self)
                    }
                }
            }
        } else {
            syntaxHighlighter.cancel()
            syntaxHighlighter.syntaxHighlight(input)
            isSyntaxHighlightingInvalid = false
            isTypesetterInvalid = true
            invokeEachAttributedStringObserver { $0.lineControllerDidUpdateAttributedString(self) }
        }
    }

    private func updateLineHeight(for lineFragments: [LineFragment]) {
        var previousNode: LineFragmentNode?
        for lineFragment in lineFragments {
            let length = lineFragment.range.length
            let data = LineFragmentNodeData(lineFragment: lineFragment)
            if lineFragment.index < lineFragmentTree.nodeTotalCount {
                let node = lineFragmentTree.node(atIndex: lineFragment.index)
                let heightDifference = abs(lineFragment.baseSize.height - node.data.lineFragmentHeight)
                if heightDifference > CGFloat.ulpOfOne {
                    _lineHeight = nil
                }
                node.value = length
                node.data.lineFragment = lineFragment
                node.updateTotalLineFragmentHeight()
                lineFragmentTree.updateAfterChangingChildren(of: node)
                previousNode = node
            } else if let thisPreviousNode = previousNode {
                let newNode = lineFragmentTree.insertNode(value: length, data: data, after: thisPreviousNode)
                newNode.updateTotalLineFragmentHeight()
                previousNode = newNode
                _lineHeight = nil
            } else {
                let thisPreviousNode = lineFragmentTree.node(atIndex: lineFragment.index - 1)
                let newNode = lineFragmentTree.insertNode(value: length, data: data, after: thisPreviousNode)
                newNode.updateTotalLineFragmentHeight()
                previousNode = newNode
                _lineHeight = nil
            }
        }
    }

    private func createLineSyntaxHighlightInput() -> LineSyntaxHighlighterInput? {
        if let attributedString = attributedString {
            let byteRange = line.data.totalByteRange
            return LineSyntaxHighlighterInput(attributedString: attributedString, byteRange: byteRange)
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

    private func redisplayLineFragments() {
        let typesetLength = typesetter.typesetLength
        _lineHeight = nil
        updateTypesetterIfNecessary()
        let newLineFragments = typesetter.typesetLineFragments(toLocation: typesetLength)
        updateLineHeight(for: newLineFragments)
        textInputProxy.lineFragments = typesetter.lineFragments
        reapplyLineFragmentToLineFragmentControllers()
        setNeedsDisplayOnLineFragmentViews()
    }
    
    private func reapplyLineFragmentToLineFragmentControllers() {
        for (_, lineFragmentController) in lineFragmentControllers {
            let lineFragmentID = lineFragmentController.lineFragment.id
            if let lineFragment = typesetter.lineFragment(withID: lineFragmentID) {
                lineFragmentController.lineFragment = lineFragment
            }
        }
    }

    private func lineFragmentControllers<T: RedBlackTreeSearchQuery>(matching query: T) -> [LineFragmentController] where T.NodeID == LineFragmentNodeID, T.NodeValue == Int, T.NodeData == LineFragmentNodeData {
        let queryResult = lineFragmentTree.search(using: query)
        return queryResult.compactMap { match in
            if let lineFragment = match.node.data.lineFragment {
                return lineFragmentController(for: lineFragment)
            } else {
                return nil
            }
        }
    }

    private func invokeEachAttributedStringObserver(_ handler: (LineControllerAttributedStringObserver) -> ()) {
        for (_, value) in attributedStringObservers {
            if let observer = value.observer {
                handler(observer)
            }
        }
    }

    private func cleanUpAttributedStringObservers() {
        attributedStringObservers = attributedStringObservers.filter { $0.value.observer != nil }
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
