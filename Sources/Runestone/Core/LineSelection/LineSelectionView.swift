#if os(macOS)
import AppKit

final class LineSelectionView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#endif
