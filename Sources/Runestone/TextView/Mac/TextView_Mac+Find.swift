#if os(macOS)
import AppKit

// The implementation of the following functions are heavily inspired by the one of STTextView: https://github.com/krzyzanowskim/STTextView
extension TextView {
    @objc func performFindPanelAction(_ sender: Any?) {
        performTextFinderAction(sender)
    }

    open override func performTextFinderAction(_ sender: Any?) {
//        guard let menuItem = sender as? NSMenuItem else {
//            assertionFailure("Expected sender to be an instance of NSMenuItem")
//            return
//        }
//        guard let action = NSTextFinder.Action(rawValue: menuItem.tag) else {
//            assertionFailure("Cannot create NSTextFinder.Action from menu item with tag \(menuItem.tag)")
//            return
//        }
//        textFinder.performAction(action)
//        textFinder.findBarContainer?.findBarView?.wantsLayer = true
//        textFinder.findBarContainer?.findBarView?.layer?.zPosition = 1000
//        if action == .showFindInterface || action == .showReplaceInterface || action == .hideFindInterface || action == .hideReplaceInterface {
//            textViewController.lineFragmentLayouter.setNeedsLayout()
//            textViewController.lineFragmentLayouter.layoutIfNeeded()
//        }
    }
}
#endif
