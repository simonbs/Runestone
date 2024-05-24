import _RunestoneObservation
import _RunestoneMultiPlatform
import Foundation

protocol Viewport: CustomDebugStringConvertible {
    var origin: CGPoint { get }
    var size: CGSize { get }
    var safeAreaInsets: MultiPlatformEdgeInsets { get }
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
    var rect: CGRect {
        CGRect(origin: origin, size: size)
    }
    var debugDescription: String {
        CGRect(origin: origin, size: size).debugDescription
    }
}
