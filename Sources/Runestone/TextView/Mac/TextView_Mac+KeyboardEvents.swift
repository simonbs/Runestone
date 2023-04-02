#if os(macOS)
import AppKit

public extension TextView {
    /// Informs the receiver that the user has pressed a key.
    /// - Parameter event: An object encapsulating information about the key-down event.
    override func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)
        let didInputContextHandleEvent = inputContext?.handleEvent(event) ?? false
        if !didInputContextHandleEvent {
            super.keyDown(with: event)
        }
    }
}
#endif
