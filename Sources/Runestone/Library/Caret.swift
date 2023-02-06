import CoreGraphics

enum Caret {
    #if os(iOS)
    static let width: CGFloat = 2
    #else
    static let width: CGFloat = 1
    #endif

    static func defaultHeight(for font: MultiPlatformFont?) -> CGFloat {
        font?.lineHeight ?? 15
    }
}
