import CoreGraphics

enum ImageRenderer {
    static func renderImage(
        ofSize size: CGSize,
        atScale scale: CGFloat = ScreenScale.rawValue,
        using renderer: (CGContext) -> Void
    ) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width * scale),
            height: Int(size.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        renderer(context)
        return context.makeImage()
    }
}
