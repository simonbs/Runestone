#if os(macOS)
import AppKit

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool {
        true
    }
}
#endif
