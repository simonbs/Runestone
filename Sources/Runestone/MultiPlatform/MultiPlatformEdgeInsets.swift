#if os(macOS)
import AppKit
public typealias MultiPlatformEdgeInsets = NSEdgeInsets
#else
import UIKit
public typealias MultiPlatformEdgeInsets = UIEdgeInsets
#endif

#if os(macOS)
extension NSEdgeInsets {
    static var zero: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

extension NSEdgeInsets: Equatable {
    public static func == (lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
    }
}
#endif
