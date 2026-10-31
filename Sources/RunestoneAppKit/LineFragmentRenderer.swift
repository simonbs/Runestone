#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Draws one engine fragment into an AppKit graphics context.
public enum LineFragmentRenderer {
    /// Draws token backgrounds, the supplied overlays, and then Core Text glyphs.
    ///
    /// The context origin must be the fragment's top-left, with y increasing
    /// downwards. The host positions the fragment using its logical-line yPosition.
    /// Prepare text with `DefaultLineTypesetterPreparation(backgroundColorKey: .backgroundColor)`
    /// to preserve AppKit token backgrounds. The caller retains ownership of clipping.
    public static func draw(_ fragment: LineFragment, in context: CGContext,
                            drawOverlays: (CGContext) -> Void = { _ in }) {
        let originalTextMatrix = context.textMatrix
        let originalTextPosition = context.textPosition
        context.saveGState()
        defer {
            context.restoreGState()
            context.textMatrix = originalTextMatrix
            context.textPosition = originalTextPosition
        }
        TokenBackgroundRenderer.draw(line: fragment.line, height: fragment.scaledSize.height, in: context,
                                     drawOverlays: { context in
            context.saveGState()
            drawOverlays(context)
            context.restoreGState()
        }, drawText: { context in
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: fragment.scaledSize.height)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = CGPoint(x: 0, y: fragment.verticalGeometry.coreTextBaseline)
            CTLineDraw(fragment.line, context)
            context.restoreGState()
        })
    }
}
#endif
