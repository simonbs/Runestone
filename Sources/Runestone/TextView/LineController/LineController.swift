// swiftlint:disable file_length
import CoreGraphics
import CoreText
import UIKit

typealias LineFragmentTree = RedBlackTree<LineFragmentNodeID, Int, LineFragmentNodeData>

protocol LineControllerDelegate: AnyObject {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter?
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController)
}

final class LineController {
    private enum TypesetAmount {
        case inRect(CGRect)
        case toLocation(Int)
        case toLineFragmentIndex(Int)
    }

    weak var delegate: LineControllerDelegate?
    let line: DocumentLineNode
    var lineFragmentHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineFragmentHeightMultiplier != oldValue {
                invalidatePrefixReuse()
                typesetter.lineFragmentHeightMultiplier = lineFragmentHeightMultiplier
            }
        }
    }
    var theme: Theme = DefaultTheme.shared {
        didSet {
            invalidateSyntaxHighlighting()
            cachedSyntaxHighlighter?.theme = theme
            applyThemeToAllLineFragmentControllers()
        }
    }
    var estimatedLineFragmentHeight: CGFloat = 15
    var tabWidth: CGFloat = 10 {
        didSet {
            if tabWidth != oldValue { invalidatePrefixReuse() }
        }
    }
    var constrainingWidth: CGFloat {
        get {
            typesetter.constrainingWidth
        }
        set {
            if typesetter.constrainingWidth != newValue { invalidatePrefixReuse() }
            typesetter.constrainingWidth = newValue
        }
    }
    var lineWidth: CGFloat {
        ceil(typesetter.maximumLineWidth)
    }
    var lineHeight: CGFloat {
        if let lineHeight = _lineHeight {
            return lineHeight
        } else if typesetter.lineFragments.isEmpty {
            let lineHeight = estimatedLineFragmentHeight * lineFragmentHeightMultiplier
            _lineHeight = lineHeight
            return lineHeight
        } else {
            // Fragment positions already accumulate all preceding scaled heights.
            let knownLineFragmentHeight = typesetter.lineFragments.last.map { $0.yPosition + $0.scaledSize.height } ?? 0
            let remainingNumberOfLineFragments = typesetter.bestGuessNumberOfLineFragments - typesetter.lineFragments.count
            let lineFragmentHeight = estimatedLineFragmentHeight * lineFragmentHeightMultiplier
            let remainingLineFragmentHeight = CGFloat(remainingNumberOfLineFragments) * lineFragmentHeight
            let lineHeight = knownLineFragmentHeight + remainingLineFragmentHeight
            _lineHeight = lineHeight
            return lineHeight
        }
    }
    var kern: CGFloat = 0 {
        didSet {
            if kern != oldValue {
                invalidatePrefixReuse()
                isDefaultAttributesInvalid = true
            }
        }
    }
    var lineBreakMode: LineBreakMode {
        get {
            typesetter.lineBreakMode
        }
        set {
            if typesetter.lineBreakMode != newValue { invalidatePrefixReuse() }
            typesetter.lineBreakMode = newValue
        }
    }
    var numberOfLineFragments: Int {
        typesetter.lineFragments.count
    }
    var isFinishedTypesetting: Bool {
        typesetter.isFinishedTypesetting
    }
    private(set) var attributedString: NSMutableAttributedString?

    private let stringView: StringView
    private let invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    private let highlightService: HighlightService
    private let typesetter: LineTypesetter
    private var cachedSyntaxHighlighter: LineSyntaxHighlighter?
    private var pendingHighlightInput: LineSyntaxHighlighterInput?
    private var lineFragmentControllers: [LineFragmentID: LineFragmentController] = [:]
    private var isLineFragmentCacheInvalid = true
    private var isStringInvalid = true
    private var isDefaultAttributesInvalid = true
    private var isSyntaxHighlightingInvalid = true
    private var isTypesetterInvalid = true
    private var allowsPrefixReuse = false
    private var isPrefixReuseInvalidated = false
    private var _lineHeight: CGFloat?
    private var lineFragmentTree: LineFragmentTree
    private var syntaxHighlighter: LineSyntaxHighlighter? {
        if let cachedSyntaxHighlighter = cachedSyntaxHighlighter {
            return cachedSyntaxHighlighter
        } else if let syntaxHighlighter = delegate?.lineSyntaxHighlighter(for: self) {
            syntaxHighlighter.theme = theme
            cachedSyntaxHighlighter = syntaxHighlighter
            return syntaxHighlighter
        } else {
            return nil
        }
    }

    init(line: DocumentLineNode,
         stringView: StringView,
         invisibleCharacterConfiguration: InvisibleCharacterConfiguration,
         highlightService: HighlightService) {
        self.line = line
        self.stringView = stringView
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
        self.highlightService = highlightService
        self.typesetter = LineTypesetter(lineID: line.id.rawValue)
        let rootLineFragmentNodeData = LineFragmentNodeData(lineFragment: nil)
        self.lineFragmentTree = LineFragmentTree(minimumValue: 0, rootValue: 0, rootData: rootLineFragmentNodeData)
    }

    deinit {
        cachedSyntaxHighlighter?.cancel()
    }

    func prepareToDisplayString(in rect: CGRect, syntaxHighlightAsynchronously: Bool) {
        prepareToDisplayString(.inRect(rect), syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
    }

    func prepareToDisplayString(toLocation location: Int, syntaxHighlightAsynchronously: Bool) {
        prepareToDisplayString(.toLocation(location), syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
    }

    func prepareToDisplayString(toLineFragmentIndex index: Int, syntaxHighlightAsynchronously: Bool) {
        prepareToDisplayString(.toLineFragmentIndex(index), syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
    }

    func cancelSyntaxHighlighting() {
        pendingHighlightInput = nil
        cachedSyntaxHighlighter?.cancel()
    }

    func invalidateEverything(allowingPrefixReuse: Bool = false) {
        // Capture clean/pending state before cancellation clears the request.
        // Repeated invalidations deliberately drop the one-shot permission.
        allowsPrefixReuse = allowingPrefixReuse && !typesetter.lineFragments.isEmpty
            && !isStringInvalid && !isDefaultAttributesInvalid && !isSyntaxHighlightingInvalid && !isTypesetterInvalid
            && pendingHighlightInput == nil && !isPrefixReuseInvalidated
        if !allowsPrefixReuse { isPrefixReuseInvalidated = true }
        cancelSyntaxHighlighting()
        isLineFragmentCacheInvalid = true
        isStringInvalid = true
        isTypesetterInvalid = true
        isDefaultAttributesInvalid = true
        isSyntaxHighlightingInvalid = true
        _lineHeight = nil
    }

    func invalidateSyntaxHighlighter() {
        invalidatePrefixReuse()
        cancelSyntaxHighlighting()
        cachedSyntaxHighlighter = nil
    }

    func invalidateSyntaxHighlighting() {
        invalidatePrefixReuse()
        cancelSyntaxHighlighting()
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

    func setMarkedTextOnLineFragments(_ range: NSRange?) {
        for (_, lineFragmentController) in lineFragmentControllers {
            let lineFragment = lineFragmentController.lineFragment
            if let range = range, range.overlaps(lineFragment.visibleRange) {
                lineFragmentController.markedRange = range
            } else {
                lineFragmentController.markedRange = nil
            }
        }
    }
}

private extension LineController {
    private func invalidatePrefixReuse() {
        allowsPrefixReuse = false
        // A later text edit cannot re-arm reuse after nontext invalidation,
        // including configuration changes that happen to return to old values.
        isPrefixReuseInvalidated = true
    }

    private func prepareToDisplayString(_ typesetAmount: TypesetAmount, syntaxHighlightAsynchronously: Bool) {
        prepareString(for: typesetAmount, syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
        typesetLineFragments(typesetAmount)
    }

    private func prepareString(for amount: TypesetAmount, syntaxHighlightAsynchronously: Bool) {
        // updateString replaces this object; defaults/highlighting mutate only the
        // new object. Never retain an additional snapshot after this preparation.
        let previous = allowsPrefixReuse && isStringInvalid && !syntaxHighlightAsynchronously ? attributedString : nil
        allowsPrefixReuse = false
        if isStringInvalid || isDefaultAttributesInvalid
            || pendingHighlightInput.map({ $0.byteRange != line.data.totalByteRange }) == true {
            cancelSyntaxHighlighting()
        }
        clearLineFragmentControllersIfNecessary()
        updateStringIfNecessary()
        updateDefaultAttributesIfNecessary()
        updateSyntaxHighlightingIfNecessary(async: syntaxHighlightAsynchronously)
        updateTypesetterIfNecessary(previous: previous, prefixLimit: previous == nil ? 0 : prefixLimit(for: amount))
    }

    private func prefixLimit(for amount: TypesetAmount) -> Int {
        // Leave the target-crossing fragment to the existing suffix loop, which
        // also preserves its additional-fragment behavior for location requests.
        switch amount {
        case .inRect(let rect):
            return typesetter.lineFragments.prefix { $0.yPosition + $0.scaledSize.height < rect.maxY }.count
        case .toLocation(let location):
            return typesetter.lineFragments.prefix { $0.range.upperBound < location }.count
        case .toLineFragmentIndex(let index):
            return min(max(0, index), typesetter.lineFragments.count)
        }
    }

    private func typesetLineFragments(_ typesetAmount: TypesetAmount) {
        let newLineFragments: [LineFragment]
        switch typesetAmount {
        case .inRect(let rect):
            newLineFragments = typesetter.typesetLineFragments(in: rect)
        case .toLocation(let location):
            // When typesetting to a location we'll typeset an additional line fragment to ensure that we can display the text surrounding that location.
            newLineFragments = typesetter.typesetLineFragments(toLocation: location, additionalLineFragmentCount: 1)
        case .toLineFragmentIndex(let index):
            let additionalCount = max(0, index + 1 - typesetter.lineFragments.count)
            newLineFragments = typesetter.typesetLineFragments(toLocation: 0, additionalLineFragmentCount: additionalCount)
        }
        updateLineHeight(for: newLineFragments)
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
            if let input = createLineSyntaxHighlightInput() {
                let defaultStringAttributes = DefaultStringAttributes(
                    textColor: theme.textColor,
                    font: theme.font,
                    kern: kern,
                    tabWidth: tabWidth
                )
                defaultStringAttributes.apply(to: input.attributedString)
            }
            isDefaultAttributesInvalid = false
            isSyntaxHighlightingInvalid = true
            isTypesetterInvalid = true
        }
    }

    private func updateTypesetterIfNecessary(previous: NSAttributedString? = nil, prefixLimit: Int = 0) {
        if isTypesetterInvalid {
            lineFragmentTree.reset(rootValue: 0, rootData: LineFragmentNodeData(lineFragment: nil))
            if let previous, let attributedString, pendingHighlightInput == nil, !isPrefixReuseInvalidated {
                let prefix = typesetter.reprepareToTypeset(attributedString, previous: previous, prefixLimit: prefixLimit)
                // Install the prefix even if the suffix request produces nothing.
                updateLineHeight(for: prefix)
            } else {
                typesetter.reset()
                if let attributedString { typesetter.prepareToTypeset(attributedString) }
            }
            isTypesetterInvalid = false
            isPrefixReuseInvalidated = false
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
            guard pendingHighlightInput == nil else {
                return
            }
            pendingHighlightInput = input
            input.isValid = { [weak self, weak input] in
                guard let self = self, let input = input else {
                    return false
                }
                return self.pendingHighlightInput === input
                    && self.line.data.totalByteRange == input.byteRange
            }
            syntaxHighlighter.syntaxHighlight(input) { [weak self] result in
                guard let self = self, self.pendingHighlightInput === input else {
                    return
                }
                self.pendingHighlightInput = nil
                if case .success(let attributesResult) = result {
                    self.didApplyHighlightAttributes(attributesResult)
                }
            }
        } else {
            cancelSyntaxHighlighting()
            syntaxHighlighter.syntaxHighlight(input)
            isSyntaxHighlightingInvalid = false
            isTypesetterInvalid = true
        }
    }

    private func didApplyHighlightAttributes(_ result: LineSyntaxHiglighterSetAttributesResult) {
        let oldWidth = lineWidth
        isSyntaxHighlightingInvalid = false
        if result.isSizingInvalid || isTypesetterInvalid {
            isTypesetterInvalid = true
            redisplayLineFragments()
        } else if let attributedString = attributedString {
            let fragments = typesetter.refreshAppearance(attributedString)
            for fragment in fragments {
                lineFragmentTree.node(atIndex: fragment.index).data.lineFragment = fragment
            }
            reapplyLineFragmentToLineFragmentControllers()
            setNeedsDisplayOnLineFragmentViews()
        }
        if abs(lineWidth - oldWidth) > CGFloat.ulpOfOne {
            delegate?.lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(self)
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
            let lineFragmentController = LineFragmentController(
                lineFragment: lineFragment,
                invisibleCharacterConfiguration: invisibleCharacterConfiguration
            )
            lineFragmentController.delegate = self
            lineFragmentControllers[lineFragment.id] = lineFragmentController
            applyTheme(to: lineFragmentController)
            return lineFragmentController
        }
    }

    private func redisplayLineFragments() {
        let typesetLength = typesetter.typesetLength
        _lineHeight = nil
        updateTypesetterIfNecessary()
        let newLineFragments = typesetter.typesetLineFragments(toLocation: typesetLength)
        updateLineHeight(for: newLineFragments)
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

    private func applyThemeToAllLineFragmentControllers() {
        for (_, lineFragmentController) in lineFragmentControllers {
            applyTheme(to: lineFragmentController)
        }
    }

    private func applyTheme(to lineFragmentController: LineFragmentController) {
        lineFragmentController.markedTextBackgroundColor = theme.markedTextBackgroundColor
        lineFragmentController.markedTextBackgroundCornerRadius = theme.markedTextBackgroundCornerRadius
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

// MARK: - UITextInput
extension LineController {
    func caretRect(atIndex lineLocalLocation: Int) -> CGRect {
        for lineFragment in typesetter.lineFragments {
            if let caretLocation = lineFragment.caretLocation(forLineLocalLocation: lineLocalLocation) {
                let xPosition = CTLineGetOffsetForStringIndex(lineFragment.line, caretLocation, nil)
                let yPosition = lineFragment.yPosition + lineFragment.verticalGeometry.textTop
                return CGRect(x: xPosition, y: yPosition, width: Caret.width, height: lineFragment.baseSize.height)
            }
        }
        let yPosition = (estimatedLineFragmentHeight * lineFragmentHeightMultiplier - estimatedLineFragmentHeight) / 2
        return CGRect(x: 0, y: yPosition, width: Caret.width, height: estimatedLineFragmentHeight)
    }

    func firstRect(for lineLocalRange: NSRange) -> CGRect {
        for lineFragment in typesetter.lineFragments {
            if let caretRange = lineFragment.caretRange(forLineLocalRange: lineLocalRange) {
                let finalIndex = min(lineFragment.visibleRange.upperBound, caretRange.upperBound)
                let xStart = CTLineGetOffsetForStringIndex(lineFragment.line, caretRange.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(lineFragment.line, finalIndex, nil)
                let yPosition = lineFragment.yPosition + lineFragment.verticalGeometry.textTop
                return CGRect(x: xStart, y: yPosition, width: xEnd - xStart, height: lineFragment.baseSize.height)
            }
        }
        return CGRect(x: 0, y: 0, width: 0, height: estimatedLineFragmentHeight * lineFragmentHeightMultiplier)
    }

    func closestIndex(to point: CGPoint) -> Int {
        guard let closestLineFragment = lineFragment(closestTo: point) else {
            return line.location
        }
        let localLocation = min(CTLineGetStringIndexForPosition(closestLineFragment.line, point), line.data.length)
        return line.location + localLocation
    }
}

// MARK: - LineFragmentControllerDelegate
extension LineController: LineFragmentControllerDelegate {
    func string(in controller: LineFragmentController) -> String? {
        let lineFragment = controller.lineFragment
        let range = NSRange(location: line.location + lineFragment.visibleRange.location, length: lineFragment.visibleRange.length)
        return stringView.substring(in: range)
    }
}
