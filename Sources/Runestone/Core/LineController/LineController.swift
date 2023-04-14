// swiftlint:disable file_length
#if os(macOS)
import AppKit
#endif
import Combine
import CoreGraphics
import CoreText
import Foundation
#if os(iOS)
import UIKit
#endif

final class LineController {
    enum TypesetAmount {
        case yPosition(CGFloat)
        case location(Int)
    }

    let line: LineNode
    @_RunestoneProxy(\LineController.typesetter.constrainingWidth)
    var constrainingWidth: CGFloat
    var lineWidth: CGFloat {
        ceil(typesetter.maximumLineFragmentWidth)
    }
    var lineHeight: CGFloat {
        if let lineHeight = _lineHeight {
            return lineHeight
        } else if typesetter.lineFragments.isEmpty {
            let lineHeight = estimatedLineHeight.scaledValue.value
            _lineHeight = lineHeight
            return lineHeight
        } else {
            let knownLineFragmentHeight = typesetter.lineFragments.reduce(0) { $0 + $1.scaledSize.height }
            let remainingNumberOfLineFragments = typesetter.bestGuessNumberOfLineFragments - typesetter.lineFragments.count
            let lineFragmentHeight = estimatedLineHeight.scaledValue.value
            let remainingLineFragmentHeight = CGFloat(remainingNumberOfLineFragments) * lineFragmentHeight
            let lineHeight = knownLineFragmentHeight + remainingLineFragmentHeight
            _lineHeight = lineHeight
            return lineHeight
        }
    }
    var numberOfLineFragments: Int {
        typesetter.lineFragments.count
    }
    var isFinishedTypesetting: Bool {
        typesetter.isFinishedTypesetting
    }
    private(set) var attributedString: NSMutableAttributedString?
    var lineFragments: [LineFragment] {
        typesetter.lineFragments
    }

    private let stringView: CurrentValueSubject<StringView, Never>
    private let estimatedLineHeight: EstimatedLineHeight
    private let tabWidth: CurrentValueSubject<CGFloat, Never>
    private let typesetter: LineTypesetter
    private let defaultStringAttributes: DefaultStringAttributes
    private let lineFragmentControllerFactory: LineFragmentControllerFactory
    private var lineFragmentControllers: [LineFragmentID: LineFragmentController] = [:]
    private var isLineFragmentCacheInvalid = true
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true
    private var _lineHeight: CGFloat?
    private var lineFragmentTree: LineFragmentTree
    private let syntaxHighlighter: SyntaxHighlighter
    private var cancellables: Set<AnyCancellable> = []

    init(
        line: LineNode,
        stringView: CurrentValueSubject<StringView, Never>,
        estimatedLineHeight: EstimatedLineHeight,
        tabWidth: CurrentValueSubject<CGFloat, Never>,
        typesetter: LineTypesetter,
        defaultStringAttributes: DefaultStringAttributes,
        lineFragmentControllerFactory: LineFragmentControllerFactory,
        syntaxHighlighter: SyntaxHighlighter
    ) {
        self.line = line
        self.stringView = stringView
        self.estimatedLineHeight = estimatedLineHeight
        self.tabWidth = tabWidth
        self.defaultStringAttributes = defaultStringAttributes
        self.lineFragmentControllerFactory = lineFragmentControllerFactory
        self.typesetter = typesetter
        self.syntaxHighlighter = syntaxHighlighter
        let rootLineFragmentNodeData = LineFragmentNodeData(lineFragment: nil)
        self.lineFragmentTree = LineFragmentTree(minimumValue: 0, rootValue: 0, rootData: rootLineFragmentNodeData)
        stringView.sink { [weak self] _ in
            self?.isStringInvalid = true
        }.store(in: &cancellables)
    }

    func prepareToDisplayString(to typesetAmount: TypesetAmount, syntaxHighlightAsynchronously: Bool) {
       prepareString(syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
       let newLineFragments: [LineFragment]
       switch typesetAmount {
       case .yPosition(let yPosition):
           newLineFragments = typesetter.typesetLineFragments(to: .yPosition(yPosition))
       case .location(let location):
           // When typesetting to a location we'll typeset an additional line fragment to ensure that we can display the text surrounding that location.
           newLineFragments = typesetter.typesetLineFragments(to: .location(location), additionalLineFragmentCount: 1)
       }
       updateLineHeight(for: newLineFragments)
   }

    func invalidateString() {
        isStringInvalid = true
    }

    func invalidateTypesetting() {
        isLineFragmentCacheInvalid = true
        isTypesetterInvalid = true
        _lineHeight = nil
    }

    func cancelSyntaxHighlighting() {
        syntaxHighlighter.cancel()
    }

    func invalidateSyntaxHighlighting() {
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
    }

    func lineFragmentControllers(in rect: CGRect) -> [LineFragmentController] {
        let lineYPosition = line.yPosition
        let localMinY = rect.minY - lineYPosition
        let localMaxY = rect.maxY - lineYPosition
        let query = LineFragmentFrameQuery(range: localMinY ... localMaxY)
        return lineFragmentControllers(matching: query)
    }

    func lineFragmentNode(containingCharacterAt location: Int) -> LineFragmentNode? {
        lineFragmentTree.node(containingLocation: location)
    }

    func lineFragmentNode(atIndex index: Int) -> LineFragmentNode {
        lineFragmentTree.node(atIndex: index)
    }

    func setNeedsDisplayOnLineFragmentViews() {
        for (_, lineFragmentController) in lineFragmentControllers {
            lineFragmentController.lineFragmentView?.setNeedsDisplay()
        }
    }

//    func setMarkedTextOnLineFragments(_ range: NSRange?) {
//        for (_, lineFragmentController) in lineFragmentControllers {
//            let lineFragment = lineFragmentController.lineFragment
//            if let range = range, range.overlaps(lineFragment.visibleRange) {
//                lineFragmentController.markedRange = range
//            } else {
//                lineFragmentController.markedRange = nil
//            }
//        }
//    }

    func firstRect(for lineLocalRange: NSRange) -> CGRect {
        for lineFragment in typesetter.lineFragments {
            if let insertionPointRange = lineFragment.insertionPointRange(forLineLocalRange: lineLocalRange) {
                let finalIndex = min(lineFragment.visibleRange.upperBound, insertionPointRange.upperBound)
                let xStart = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(lineFragment.line, finalIndex, nil)
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                return CGRect(x: xStart, y: yPosition, width: xEnd - xStart, height: lineFragment.baseSize.height)
            }
        }
        return CGRect(x: 0, y: 0, width: 0, height: estimatedLineHeight.scaledValue.value)
    }

    func location(closestTo point: CGPoint) -> Int {
        guard let closestLineFragment = lineFragment(closestTo: point) else {
            return line.location
        }
        let localLocation = min(CTLineGetStringIndexForPosition(closestLineFragment.line, point), line.data.length)
        return line.location + localLocation
    }
}

private extension LineController {
    private func prepareString(syntaxHighlightAsynchronously: Bool) {
        syntaxHighlighter.cancel()
        clearLineFragmentControllersIfNeeded()
        updateStringIfNeeded()
        updateDefaultAttributesIfNeeded()
        updateSyntaxHighlightingIfNeeded(async: syntaxHighlightAsynchronously)
        updateTypesetterIfNeeded()
    }

    private func clearLineFragmentControllersIfNeeded() {
        if isLineFragmentCacheInvalid {
            lineFragmentControllers.removeAll(keepingCapacity: true)
            isLineFragmentCacheInvalid = false
        }
    }

    private func updateStringIfNeeded() {
        if isStringInvalid {
            let range = NSRange(location: line.location, length: line.data.totalLength)
            if let string = stringView.value.substring(in: range) {
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

    private func updateDefaultAttributesIfNeeded() {
        if isDefaultAttributesInvalid {
            if let input = createLineSyntaxHighlightInput() {
                defaultStringAttributes.apply(to: input.attributedString)
            }
            updateParagraphStyle()
            isDefaultAttributesInvalid = false
            isSyntaxHighlightingInvalid = true
            isTypesetterInvalid = true
        }
    }

    private func updateParagraphStyle() {
        if let attributedString = attributedString {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = []
            paragraphStyle.defaultTabInterval = tabWidth.value
            let range = NSRange(location: 0, length: attributedString.length)
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }

    private func updateTypesetterIfNeeded() {
        if isTypesetterInvalid {
            lineFragmentTree.reset(rootValue: 0, rootData: LineFragmentNodeData(lineFragment: nil))
            typesetter.reset()
            if let attributedString = attributedString {
                typesetter.prepareToTypeset(attributedString)
            }
            isTypesetterInvalid = false
        }
    }

    private func updateSyntaxHighlightingIfNeeded(async: Bool) {
        guard isSyntaxHighlightingInvalid else {
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
                    self.isSyntaxHighlightingInvalid = false
                    self.isTypesetterInvalid = true
                    self.redisplayLineFragments()
                }
            }
        } else {
            syntaxHighlighter.cancel()
            syntaxHighlighter.syntaxHighlight(input)
            isSyntaxHighlightingInvalid = false
            isTypesetterInvalid = true
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

    private func createLineSyntaxHighlightInput() -> SyntaxHighlighterInput? {
        guard let attributedString = attributedString else {
            return nil
        }
        let byteRange = line.data.totalByteRange
        return SyntaxHighlighterInput(attributedString: attributedString, byteRange: byteRange)
    }

    private func lineFragmentController(for lineFragment: LineFragment) -> LineFragmentController {
        if let lineFragmentController = lineFragmentControllers[lineFragment.id] {
            lineFragmentController.lineFragment = lineFragment
            return lineFragmentController
        } else {
            let lineFragmentController = lineFragmentControllerFactory.makeLineFragmentController(for: lineFragment, in: line)
            lineFragmentControllers[lineFragment.id] = lineFragmentController
            return lineFragmentController
        }
    }

    private func redisplayLineFragments() {
        let typesetLength = typesetter.typesetLength
        _lineHeight = nil
        updateTypesetterIfNeeded()
        let newLineFragments = typesetter.typesetLineFragments(to: .location(typesetLength))
        updateLineHeight(for: newLineFragments)
        reapplyLineFragmentToLineFragmentControllers()
        setNeedsDisplayOnLineFragmentViews()
//        delegate?.lineControllerDidInvalidateSize(self)
    }

    private func reapplyLineFragmentToLineFragmentControllers() {
        for (_, lineFragmentController) in lineFragmentControllers {
            let lineFragmentID = lineFragmentController.lineFragment.id
            if let lineFragment = typesetter.lineFragment(withID: lineFragmentID) {
                lineFragmentController.lineFragment = lineFragment
            }
        }
    }

    private func lineFragmentControllers<T: RedBlackTreeSearchQuery>(matching query: T)
    -> [LineFragmentController] where T.NodeID == LineFragmentNodeID, T.NodeValue == Int, T.NodeData == LineFragmentNodeData {
        let queryResult = lineFragmentTree.search(using: query)
        return queryResult.compactMap { match in
            if let lineFragment = match.node.data.lineFragment {
                return lineFragmentController(for: lineFragment)
            } else {
                return nil
            }
        }
    }

    private func lineFragment(closestTo point: CGPoint) -> LineFragment? {
        var closestLineFragment = typesetter.lineFragments.last
        for lineFragment in typesetter.lineFragments {
            let lineMaxY = lineFragment.yPosition + lineFragment.scaledSize.height
            if point.y <= lineMaxY {
                closestLineFragment = lineFragment
                break
            }
        }
        return closestLineFragment
    }
}
