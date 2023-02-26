import Foundation

class FlippedView: MultiPlatformView {
    #if os(macOS)
    override var isFlipped: Bool {
        true
    }
    #endif
}
