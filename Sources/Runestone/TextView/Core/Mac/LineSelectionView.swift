#if os(macOS)
import AppKit

final class LineSelectionView: NSView, ReusableView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#endif
