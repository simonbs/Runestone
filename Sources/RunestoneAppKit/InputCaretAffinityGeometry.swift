#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Resolves the visual identity of a caret from already prepared viewport
/// geometry. It never lays out, scrolls, or chooses between bidi alternatives.
enum InputCaretAffinityGeometry {
    static func requiresAffinity(at location: Int, in view: ReadOnlyDocumentView) -> Bool {
        guard let line = view.manager.line(containingCharacterAt: location),
              let lineLayout = view.visibleLayout?.lines.first(where: { $0.line === line }) else { return false }
        let local = min(location, line.location + line.data.length) - line.location
        let candidates = lineLayout.placements.filter {
            $0.fragment.range.location <= local && local <= $0.fragment.range.upperBound
        }
        if candidates.count > 1 { return true }
        guard let placement = candidates.first else { return false }
        var secondary: CGFloat = 0
        let primary = CTLineGetOffsetForStringIndex(placement.fragment.line, local, &secondary)
        return primary.isFinite && secondary.isFinite && abs(primary - secondary) > 0.01
    }

    static func target(forDocumentPoint point: NSPoint,
                       lineLayout: ViewportLayoutCoordinator.LineLayout,
                       placement: LogicalLineLayoutController.Placement,
                       location: Int, in view: ReadOnlyDocumentView) -> InputCaretTarget? {
        let line = lineLayout.line
        let local = location - line.location
        guard local >= 0, local <= line.data.length else { return nil }
        var secondary: CGFloat = 0
        let primary = CTLineGetOffsetForStringIndex(placement.fragment.line, local, &secondary)
        guard primary.isFinite, secondary.isFinite else { return nil }
        // Bidi affinity is part of the model, but remains unavailable until
        // keyboard, pointer, IME and AX traversal all share it end to end.
        guard abs(primary - secondary) <= 0.01 else { return nil }

        let placements = lineLayout.placements
        guard let index = placements.firstIndex(where: { $0.fragment.id == placement.fragment.id }) else { return nil }
        let range = placement.fragment.range
        let wrapSide: InputCaretAffinity.WrapSide?
        if index > 0, local == range.location,
           placements[index - 1].fragment.range.upperBound == local {
            wrapSide = .downstream
        } else if index + 1 < placements.count, local == range.upperBound,
                  placements[index + 1].fragment.range.location == local {
            wrapSide = .upstream
        } else {
            wrapSide = nil
        }
        let affinity = wrapSide.map {
            InputCaretAffinity(wrapSide: $0, bidirectionalSide: nil,
                               layoutRevision: view.inputLayoutRevision)
        }
        return InputCaretTarget(location: location, affinity: affinity)
    }

    static func documentRect(for target: InputCaretTarget, in view: ReadOnlyDocumentView,
                             caretWidth: CGFloat = 1) -> NSRect? {
        guard target.location >= 0, target.location <= view.manager.stringView.string.length,
              let line = view.manager.line(containingCharacterAt: target.location),
              let layout = view.visibleLayout,
              let lineLayout = layout.lines.first(where: { $0.line === line }) else { return nil }
        if let affinity = target.affinity {
            guard affinity.layoutRevision == view.inputLayoutRevision,
                  affinity.bidirectionalSide == nil else { return nil }
        }
        let local = min(target.location, line.location + line.data.length) - line.location
        let candidates = lineLayout.placements.filter {
            $0.fragment.range.location <= local && local <= $0.fragment.range.upperBound
        }
        let placement: LogicalLineLayoutController.Placement?
        switch target.affinity?.wrapSide {
        case .upstream:
            placement = candidates.first(where: {
                local == $0.fragment.range.upperBound && $0.fragment.range.upperBound < line.data.length
            })
        case .downstream:
            placement = candidates.last(where: {
                local == $0.fragment.range.location && $0.fragment.range.location > 0
            })
        case nil:
            guard candidates.count <= 1 else { return nil }
            placement = candidates.first
        }
        if let placement {
            return InputCaretGeometry.rect(for: placement, lineStart: line.location,
                                           documentOffset: target.location, caretWidth: caretWidth)
        }
        guard line.data.length == 0 else { return nil }
        return NSRect(x: 0, y: line.yPosition, width: caretWidth, height: line.data.lineHeight)
    }
}
#endif
