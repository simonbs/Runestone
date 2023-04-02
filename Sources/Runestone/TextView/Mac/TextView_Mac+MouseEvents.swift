#if os(macOS)
import AppKit

public extension TextView {
    /// Informs the receiver that the user has pressed the left mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-down event.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let location = locationClosestToPoint(in: event)
        if event.clickCount == 1 {
            textViewController.locationNavigator.move(to: location)
            textViewController.selectionNavigator.startDraggingSelection(from: location)
        } else if event.clickCount == 2 {
            textViewController.selectionNavigator.selectWord(at: location)
        } else if event.clickCount == 3 {
            textViewController.selectionNavigator.selectLine(at: location)
        }
    }

    /// Informs the receiver that the user has moved the mouse with the left button pressed.
    /// - Parameter event: An object encapsulating information about the mouse-dragged event.
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let location = locationClosestToPoint(in: event)
        textViewController.selectionNavigator.extendDraggedSelection(to: location)
    }

    /// Informs the receiver that the user has released the left mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-up event.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 1 {
            let location = locationClosestToPoint(in: event)
            textViewController.selectionNavigator.extendDraggedSelection(to: location)
        }
    }

    /// Informs the receiver that the user has pressed the right mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-down event.
    override func rightMouseDown(with event: NSEvent) {
        let location = locationClosestToPoint(in: event)
        let selectedRange = textViewController.selectedRange.value
        if !selectedRange.contains(location) {
            textViewController.selectionNavigator.selectWord(at: location)
        }
        super.rightMouseDown(with: event)
    }
}

private extension TextView {
    private func locationClosestToPoint(in event: NSEvent) -> Int {
        let point = convert(event.locationInWindow, from: nil)
        return characterIndex(for: point)
    }
}
#endif
