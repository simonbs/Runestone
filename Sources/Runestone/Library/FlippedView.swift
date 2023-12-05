import _RunestoneMultiPlatform

class FlippedView: MultiPlatformView {
    #if os(macOS)
    override var isFlipped: Bool {
        true
    }
    #endif
}
