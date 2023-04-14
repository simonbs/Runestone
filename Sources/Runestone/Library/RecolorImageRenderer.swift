import CoreGraphics

enum RecolorImageRenderer {
    static func render(_ image: CGImage, withColor color: MultiPlatformColor, in frame: CGRect, to context: CGContext) {
        context.saveGState()
        context.clip(to: frame, mask: image)
        context.setFillColor(color.cgColor)
        context.fill(frame)
        context.restoreGState()
    }
}
