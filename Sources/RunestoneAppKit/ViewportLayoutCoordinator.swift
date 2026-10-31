#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// Resolves a viewport against the changing estimated heights in the line index.
/// The host owns and invalidates controllers after edits or typography changes.
final class ViewportLayoutCoordinator {
    struct LineLayout {
        let line: DocumentLineNode
        let controller: LogicalLineLayoutController
        let placements: [LogicalLineLayoutController.Placement]
    }

    struct Result {
        let viewport: CGRect
        let contentOffsetAdjustmentY: CGFloat
        let lines: [LineLayout]
        let isComplete: Bool
    }

    private let manager: LineManager
    private let controllerForLine: (DocumentLineNode) -> LogicalLineLayoutController?
    private var previousLines: [DocumentLineNode] = []

    /// The provider must return a prepared controller for the current line, or
    /// nil if preparation fails. Preparation may itself change indexed height.
    init(manager: LineManager, controllerForLine: @escaping (DocumentLineNode) -> LogicalLineLayoutController?) {
        self.manager = manager
        self.controllerForLine = controllerForLine
    }

    /// Returns nil for an invalid viewport. Even an incomplete result carries an
    /// adjustment that the host must apply before retrying. Complete placements
    /// and the corrected viewport belong to the same transaction.
    func layout(in requestedViewport: CGRect) -> Result? {
        guard requestedViewport.minX.isFinite, requestedViewport.minY.isFinite,
              requestedViewport.width.isFinite, requestedViewport.height.isFinite,
              requestedViewport.maxX.isFinite, requestedViewport.maxY.isFinite,
              requestedViewport.width > 0, requestedViewport.height > 0 else { return nil }
        var viewport = requestedViewport
        var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
        func controller(for line: DocumentLineNode) -> LogicalLineLayoutController? {
            if let cached = controllers[line.id] { return cached }
            guard let prepared = controllerForLine(line) else { return nil }
            controllers[line.id] = prepared
            return prepared
        }
        let overlapping = previousLines.filter { line in
            isAttachedAndVisible(line) && line.yPosition + line.data.lineHeight > viewport.minY && line.yPosition < viewport.maxY
        }
        let anchor = overlapping.min { $0.yPosition < $1.yPosition }
            ?? manager.line(containingYOffset: min(max(0, viewport.minY), manager.contentHeight))
        guard let anchor = anchor else { return nil }
        let oldAnchorY = anchor.yPosition
        var remaining = max(0, oldAnchorY - viewport.minY + viewport.height * 0.5)
        var preceding = manager.previousVisibleLine(before: anchor)
        while let line = preceding, remaining > 0 {
            guard let controller = controller(for: line) else {
                viewport.origin.y += anchor.yPosition - oldAnchorY
                return Result(viewport: viewport, contentOffsetAdjustmentY: viewport.minY - requestedViewport.minY,
                              lines: [], isComplete: false)
            }
            _ = controller.layout(.toLocation(line.data.length))
            remaining -= line.data.lineHeight
            preceding = manager.previousVisibleLine(before: line)
        }
        viewport.origin.y += anchor.yPosition - oldAnchorY

        let startY = min(max(0, viewport.minY), manager.contentHeight)
        var next = manager.line(containingYOffset: startY)
        var layouts: [LineLayout] = []
        while let line = next, line.yPosition < viewport.maxY {
            guard let controller = controller(for: line) else {
                return Result(viewport: viewport, contentOffsetAdjustmentY: viewport.minY - requestedViewport.minY,
                              lines: [], isComplete: false)
            }
            var placements = controller.layout(.inRect(localViewport(viewport, for: line)))
            // Finishing an overestimated first line may leave the requested top
            // beyond its actual tail. Re-resolve before publishing placements.
            if layouts.isEmpty && controller.isFinishedTypesetting && line.yPosition + line.data.lineHeight <= viewport.minY {
                viewport.origin.y += max(line.yPosition, line.yPosition + line.data.lineHeight - viewport.height) - viewport.minY
                placements = controller.layout(.inRect(localViewport(viewport, for: line)))
            }
            layouts.append(LineLayout(line: line, controller: controller, placements: placements))
            next = manager.nextVisibleLine(after: line)
        }
        previousLines = layouts.map(\.line)
        return Result(viewport: viewport, contentOffsetAdjustmentY: viewport.minY - requestedViewport.minY,
                      lines: layouts, isComplete: true)
    }

    private func localViewport(_ viewport: CGRect, for line: DocumentLineNode) -> CGRect {
        CGRect(x: viewport.minX, y: max(0, viewport.minY - line.yPosition), width: viewport.width,
               height: max(0, viewport.maxY - max(viewport.minY, line.yPosition)))
    }

    private func isAttachedAndVisible(_ line: DocumentLineNode) -> Bool {
        let row = line.index
        return row >= 0 && row < manager.lineCount && manager.line(atRow: row) === line && !manager.isLineHidden(row)
    }
}
#endif
