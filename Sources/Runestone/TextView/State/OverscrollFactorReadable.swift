import CoreGraphics

protocol OverscrollFactorReadable {
    var verticalOverscrollFactor: CGFloat { get }
    var horizontalOverscrollFactor: CGFloat { get }
}
