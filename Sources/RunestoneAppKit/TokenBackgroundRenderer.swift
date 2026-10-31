#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Prepares and paints token backgrounds in an AppKit line-fragment drawing pass.
public enum TokenBackgroundRenderer {
    /// Preserves the input while moving AppKit background colors to the engine's drawing attribute.
    public static func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString {
        TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: .backgroundColor)
    }

    /// Draws token backgrounds, then overlays, then text, in the caller's line-local coordinates.
    /// The caller provides the fragment height and is responsible for positioning the context.
    public static func draw(line: CTLine, height: CGFloat, in context: CGContext,
                            drawOverlays: (CGContext) -> Void, drawText: (CGContext) -> Void) {
        context.saveGState()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let color = attributes[TokenBackgroundMapping.attributeKey] as? NSColor,
                  let bounds = CoreTextRunGeometry.horizontalBounds(of: run) else { continue }
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: bounds.lowerBound, y: 0,
                                width: bounds.upperBound - bounds.lowerBound, height: height))
        }
        context.restoreGState()
        drawOverlays(context)
        drawText(context)
    }
}
#endif
