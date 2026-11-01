#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// Owns incremental AppKit layout for one node in the shared line index.
/// The host must invalidate this controller for edited or removed lines and
/// reprepare after changes to text, attributes, width, or typography.
final class LogicalLineLayoutController {
    enum TargetPlacement {
        case found(Placement)
        case pending
        case unavailable
    }
    struct Placement {
        let fragment: LineFragment
        let documentRange: NSRange
        let frame: CGRect
        fileprivate let ownerID: UUID
        fileprivate let generation: UInt
    }

    var isFinishedTypesetting: Bool { prepared && typesetter.isFinishedTypesetting }
    private(set) var measuredTextWidth: CGFloat = 0

    /// A completed typesetter needs no further preceding-line layout only if
    /// its measured height is still the one installed in the shared index.
    var hasCurrentFinishedHeight: Bool {
        guard isFinishedTypesetting, isAttached else { return false }
        let measured = typesetter.estimatedLineHeight(fragmentHeight: fallbackHeight)
        return measured.isFinite && abs(measured - line.data.lineHeight) < CGFloat.ulpOfOne
    }

    /// Defend the cached lookup against a controller for another line.
    func hasCurrentFinishedHeight(for expectedLine: DocumentLineNode) -> Bool {
        line === expectedLine && hasCurrentFinishedHeight
    }

    private let manager: LineManager
    private let line: DocumentLineNode
    private let typesetter: LineTypesetter
    private var fallbackHeight: CGFloat = 0
    private var prepared = false
    private let ownerID = UUID()
    private var generation: UInt = 0

    init(manager: LineManager, line: DocumentLineNode) {
        self.manager = manager
        self.line = line
        self.typesetter = LineTypesetter(lineID: line.id.rawValue,
                                         preparation: AppKitLineTypesetterPreparation())
    }

    /// Resets cached fragments and validates that the attributed input is the
    /// complete current line, including its delimiter, in UTF-16 coordinates.
    @discardableResult
    func prepare(_ input: NSAttributedString, width: CGFloat, heightMultiplier: CGFloat = 1,
                 fallbackHeight: CGFloat, lineBreakMode: LineBreakMode = .byWordWrapping,
                 wrapsLines: Bool = true) -> Bool {
        invalidate()
        guard isAttached, width.isFinite, width > 0, heightMultiplier.isFinite, heightMultiplier > 0,
              fallbackHeight.isFinite, fallbackHeight > 0,
              (fallbackHeight * heightMultiplier).isFinite else { return false }
        let location = line.location
        let length = line.data.totalLength
        let string = manager.stringView.string
        guard location >= 0, length >= 0, location <= string.length, length <= string.length - location else { return false }
        guard input.length == length else { return false }
        let inputString = input.string as NSString
        for index in 0..<length where inputString.character(at: index) != string.character(at: location + index) {
            return false
        }
        self.fallbackHeight = fallbackHeight
        if wrapsLines {
            measuredTextWidth = 0
            typesetter.constrainingWidth = width
        } else {
            let line = CTLineCreateWithAttributedString(input)
            let measured = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            measuredTextWidth = measured.isFinite ? max(0, ceil(measured)) : 0
            // One finite fragment preserves Core Text geometry without asking the
            // engine to invent an unbounded layout width.
            typesetter.constrainingWidth = max(1, measuredTextWidth + 1)
        }
        typesetter.lineFragmentHeightMultiplier = heightMultiplier
        typesetter.lineBreakMode = lineBreakMode
        typesetter.prepareToTypeset(input)
        prepared = true
        manager.setHeight(of: line, to: typesetter.estimatedLineHeight(fragmentHeight: fallbackHeight))
        return true
    }

    /// Discards cached input and fragments. The owner calls this on line edits.
    func invalidate() {
        prepared = false
        measuredTextWidth = 0
        generation &+= 1
        typesetter.reset()
    }

    /// Typesets incrementally and returns known fragments in document coordinates.
    /// Rectangle requests return only fragments intersecting the line-local rect.
    /// Placements are snapshots; request them again after document geometry changes.
    func layout(_ request: LogicalLineLayoutRequest, horizontalInset: CGFloat = 0) -> [Placement] {
        guard prepared, isAttached else { return [] }
        typesetter.typeset(request)
        manager.setHeight(of: line, to: typesetter.estimatedLineHeight(fragmentHeight: fallbackHeight))
        let fragments = typesetter.lineFragments
        let selected: ArraySlice<LineFragment>
        if case .inRect(let rect) = request {
            var lower = 0
            var upper = fragments.count
            while lower < upper {
                let middle = (lower + upper) / 2
                let fragment = fragments[middle]
                if fragment.yPosition + fragment.scaledSize.height <= rect.minY { lower = middle + 1 }
                else { upper = middle }
            }
            var end = lower
            while end < fragments.count && fragments[end].yPosition < rect.maxY { end += 1 }
            selected = fragments[lower..<end]
        } else {
            selected = fragments[...]
        }
        let lineStart = line.location
        let lineY = line.yPosition
        return selected.map { fragment in
            Placement(fragment: fragment,
                      documentRange: NSRange(location: lineStart + fragment.visibleRange.location,
                                             length: fragment.visibleRange.length),
                      frame: CGRect(x: horizontalInset, y: lineY + fragment.yPosition,
                                    width: fragment.scaledSize.width, height: fragment.scaledSize.height),
                      ownerID: ownerID, generation: generation)
        }
    }

    /// Incrementally prepares a wrapped fragment containing a document UTF-16
    /// location. Each call creates at most `maximumNewFragmentCount` fragments;
    /// callers schedule another turn for `.pending`.
    func prepareTargetPlacement(at documentLocation: Int, maximumNewFragmentCount: Int,
                                horizontalInset: CGFloat = 0) -> TargetPlacement {
        guard prepared, isAttached, maximumNewFragmentCount > 0 else { return .unavailable }
        let local = documentLocation - line.location
        guard local >= 0, local <= line.data.length else { return .unavailable }
        func target() -> LineFragment? {
            if local == line.data.length { return typesetter.lineFragments.last }
            return typesetter.lineFragments.first { fragment in
                fragment.range.location <= local && local < fragment.range.upperBound
            }
        }
        if let fragment = target() { return .found(placement(fragment, horizontalInset: horizontalInset)) }
        _ = typesetter.typesetLineFragments(toLocation: local,
                                            maximumNewLineFragmentCount: maximumNewFragmentCount)
        manager.setHeight(of: line, to: typesetter.estimatedLineHeight(fragmentHeight: fallbackHeight))
        if let fragment = target() { return .found(placement(fragment, horizontalInset: horizontalInset)) }
        return typesetter.isFinishedTypesetting ? .unavailable : .pending
    }

    /// Draws current placements in the caller's top-down document coordinates.
    /// The caller owns clipping. Invalidated placements are ignored and the
    /// line's current position is used even if preceding heights have changed.
    func draw(_ placements: [Placement], in context: CGContext) {
        guard prepared, isAttached else { return }
        let lineY = line.yPosition
        for placement in placements where placement.ownerID == ownerID && placement.generation == generation {
            context.saveGState()
            context.translateBy(x: placement.frame.minX, y: lineY + placement.fragment.yPosition)
            LineFragmentRenderer.draw(placement.fragment, in: context)
            context.restoreGState()
        }
    }

    private var isAttached: Bool {
        let row = line.index
        return row >= 0 && row < manager.lineCount && manager.line(atRow: row) === line
    }

    private func placement(_ fragment: LineFragment, horizontalInset: CGFloat) -> Placement {
        Placement(fragment: fragment,
                  documentRange: NSRange(location: line.location + fragment.visibleRange.location,
                                         length: fragment.visibleRange.length),
                  frame: CGRect(x: horizontalInset, y: line.yPosition + fragment.yPosition,
                                width: fragment.scaledSize.width, height: fragment.scaledSize.height),
                  ownerID: ownerID, generation: generation)
    }
}
#endif
