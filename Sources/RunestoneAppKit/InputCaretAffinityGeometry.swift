#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Resolves the visual identity of a caret from already prepared viewport
/// geometry. It never lays out or scrolls, and refuses unresolved ties or
/// coincident visual caret identities.
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
                       in view: ReadOnlyDocumentView) -> InputCaretTarget? {
        let line = lineLayout.line
        let placements = lineLayout.placements
        guard let index = placements.firstIndex(where: { $0.fragment.id == placement.fragment.id }) else { return nil }
        let visible = placement.fragment.visibleRange
        let contentEnd = min(visible.upperBound, line.data.length)
        let text = view.manager.stringView.string
        guard visible.location >= 0, visible.location <= contentEnd else { return nil }
        struct Candidate: Equatable {
            let location: Int
            let x: CGFloat
            let bidi: InputCaretAffinity.BidirectionalSide?
            let ownsRight: Bool
        }
        var candidates: [Candidate] = []
        CTLineEnumerateCaretOffsets(placement.fragment.line) { offset, localIndex, leading, _ in
            guard offset.isFinite, localIndex >= visible.location, localIndex < contentEnd,
                  line.location <= Int.max - localIndex else { return }
            let absolute = line.location + localIndex
            guard absolute >= 0, absolute < text.length else { return }
            let cluster = text.rangeOfComposedCharacterSequence(at: absolute)
            let location = leading ? cluster.location : cluster.upperBound
            guard location >= line.location + visible.location,
                  location <= line.location + contentEnd else { return }
            let local = location - line.location
            var secondary: CGFloat = 0
            let primary = CTLineGetOffsetForStringIndex(placement.fragment.line, local, &secondary)
            guard primary.isFinite, secondary.isFinite else { return }
            let bidi: InputCaretAffinity.BidirectionalSide?
            if abs(primary - secondary) > 0.01 {
                if abs(offset - primary) <= 0.01 { bidi = .primary }
                else if abs(offset - secondary) <= 0.01 { bidi = .secondary }
                else { return }
            } else { bidi = nil }
            let runs = CTLineGetGlyphRuns(placement.fragment.line) as? [CTRun]
            let run = runs?.first(where: {
                let range = CTRunGetStringRange($0)
                return range.location <= localIndex && localIndex < range.location + range.length
            })
            let rtl = run.map { CTRunGetStatus($0).contains(.rightToLeft) } ?? false
            let candidate = Candidate(location: location, x: placement.frame.minX + offset,
                                      bidi: bidi, ownsRight: leading != rtl)
            if !candidates.contains(candidate) { candidates.append(candidate) }
        }
        guard !candidates.isEmpty else { return nil }
        let distances = candidates.map { abs(point.x - $0.x) }
        guard let nearest = distances.min() else { return nil }
        let nearestCandidates = zip(candidates, distances).filter { abs($0.1 - nearest) <= 0.01 }.map(\.0)
        let nearestXs = Set(nearestCandidates.map { Int(($0.x * 100).rounded()) })
        guard nearestXs.count == 1 else { return nil }
        var resolvedCandidates = nearestCandidates
        let identitiesBeforeDirection = resolvedCandidates.map { ($0.location, $0.bidi) }
        if let firstIdentity = identitiesBeforeDirection.first,
           !identitiesBeforeDirection.allSatisfy({ $0.0 == firstIdentity.0 && $0.1 == firstIdentity.1 }) {
            guard let x = resolvedCandidates.first?.x else { return nil }
            let delta = point.x - x
            guard abs(delta) > 0.01 else { return nil }
            resolvedCandidates = resolvedCandidates.filter { $0.ownsRight == (delta > 0) }
        }
        let identities = resolvedCandidates.map { ($0.location, $0.bidi) }
        guard let first = identities.first,
              identities.allSatisfy({ $0.0 == first.0 && $0.1 == first.1 }) else { return nil }
        let local = first.0 - line.location
        let range = placement.fragment.range
        let wrapSide: InputCaretAffinity.WrapSide?
        if index > 0, local == range.location,
           placements[index - 1].fragment.range.upperBound == local { wrapSide = .downstream }
        else if index + 1 < placements.count, local == range.upperBound,
                placements[index + 1].fragment.range.location == local { wrapSide = .upstream }
        else { wrapSide = nil }
        guard wrapSide == nil || first.1 == nil else { return nil }
        let affinity = wrapSide != nil || first.1 != nil
            ? InputCaretAffinity(wrapSide: wrapSide, bidirectionalSide: first.1,
                                 layoutRevision: view.inputLayoutRevision) : nil
        return InputCaretTarget(location: first.0, affinity: affinity)
    }

    static func documentRect(for target: InputCaretTarget, in view: ReadOnlyDocumentView,
                             caretWidth: CGFloat = 1) -> NSRect? {
        guard target.location >= 0, target.location <= view.manager.stringView.string.length,
              let line = view.manager.line(containingCharacterAt: target.location),
              let layout = view.visibleLayout,
              let lineLayout = layout.lines.first(where: { $0.line === line }) else { return nil }
        if let affinity = target.affinity {
            guard affinity.layoutRevision == view.inputLayoutRevision,
                  affinity.wrapSide == nil || affinity.bidirectionalSide == nil else { return nil }
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
            guard var rect = InputCaretGeometry.rect(for: placement, lineStart: line.location,
                                                     documentOffset: target.location, caretWidth: caretWidth) else { return nil }
            if let bidiSide = target.affinity?.bidirectionalSide {
                var secondary: CGFloat = 0
                let primary = CTLineGetOffsetForStringIndex(placement.fragment.line, local, &secondary)
                guard primary.isFinite, secondary.isFinite, abs(primary - secondary) > 0.01 else { return nil }
                rect.origin.x = placement.frame.minX + (bidiSide == .primary ? primary : secondary)
            }
            return rect
        }
        guard line.data.length == 0 else { return nil }
        return NSRect(x: 0, y: line.yPosition, width: caretWidth, height: line.data.lineHeight)
    }
}
#endif
