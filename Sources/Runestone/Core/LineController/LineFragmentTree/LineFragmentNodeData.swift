import CoreGraphics

final class LineFragmentNodeData {
    var lineFragment: LineFragment?
    var lineFragmentHeight: CGFloat {
        lineFragment?.scaledSize.height ?? 0
    }
    var totalLineFragmentHeight: CGFloat = 0

    init(lineFragment: LineFragment?) {
        self.lineFragment = lineFragment
    }
}
