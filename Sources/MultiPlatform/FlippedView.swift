import Foundation

open class FlippedView: MultiPlatformView {
    #if os(macOS)
    public override var isFlipped: Bool {
        true
    }
    #endif
}
