#if os(macOS)
import AppKit

public extension TextView {
    /// Informs the receiver that the user has pressed the left mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-down event.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let location = locationClosestToPoint(in: event)
        if event.clickCount == 1 {
            textViewController.move(to: location)
            textViewController.startDraggingSelection(from: location)
        } else if event.clickCount == 2 {
            textViewController.selectWord(at: location)
        } else if event.clickCount == 3 {
            textViewController.selectLine(at: location)
        }
    }

    /// Informs the receiver that the user has moved the mouse with the left button pressed.
    /// - Parameter event: An object encapsulating information about the mouse-dragged event.
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let location = locationClosestToPoint(in: event)
        textViewController.extendDraggedSelection(to: location)
    }

    /// Informs the receiver that the user has released the left mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-up event.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 1 {
            let location = locationClosestToPoint(in: event)
            textViewController.extendDraggedSelection(to: location)
        }
    }

    /// Informs the receiver that the user has pressed the right mouse button.
    /// - Parameter event: An object encapsulating information about the mouse-down event.
    override func rightMouseDown(with event: NSEvent) {
        let location = locationClosestToPoint(in: event)
        if let selectedRange = textViewController.selectedRange, !selectedRange.contains(location) || textViewController.selectedRange == nil {
            textViewController.selectWord(at: location)
        }
        super.rightMouseDown(with: event)
    }
}

private extension TextView {
    private func locationClosestToPoint(in event: NSEvent) -> Int {
        let point = scrollContentView.convert(event.locationInWindow, from: nil)
        return characterIndex(for: point)
    }
}
#endif
