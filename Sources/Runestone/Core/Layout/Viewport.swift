import Foundation

protocol Viewport {
    var origin: CGPoint { get }
    var size: CGSize { get }
}

extension Viewport {
    var width: CGFloat {
        size.width
    }

    var height: CGFloat {
        size.height
    }

    var minX: CGFloat {
        origin.x
    }

    var minY: CGFloat {
        origin.y
    }

    var maxY: CGFloat {
        origin.y + size.height
    }
}
