import CoreGraphics

enum Caret {
    static let width: CGFloat = 2

    static func defaultHeight(for font: MultiPlatformFont?) -> CGFloat {
        return font?.lineHeight ?? 15
    }
}
