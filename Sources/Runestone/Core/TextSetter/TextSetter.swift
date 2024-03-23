import Foundation

final class TextSetter<StringViewType: StringView, LineManagerType: LineManaging> {
    typealias State = SelectedRangeWritable

    private let state: State
    private let stringView: StringViewType
    private let lineManager: LineManagerType
    private let viewportRenderer: ViewportRendering

    init(
        state: State,
        stringView: StringViewType,
        lineManager: LineManagerType,
        viewportRenderer: ViewportRendering
    ) {
        self.state = state
        self.stringView = stringView
        self.lineManager = lineManager
        self.viewportRenderer = viewportRenderer
    }

    func setText(_ newText: String) {
        guard newText != stringView.string else {
            return
        }
        let oldSelectedRange = state.selectedRange
        stringView.string = newText
//        languageMode.parse(newText as NSString)
        lineManager.rebuild()
//        textInputDelegate.selectionWillChange()
        state.selectedRange = oldSelectedRange.capped(to: stringView.length)
//        textInputDelegate.selectionDidChange()
//        contentSizeService.reset()
//        gutterWidthService.invalidateLineNumberWidth()
//        highlightedRangeService.invalidateHighlightedRangeFragments()
//        invalidateLines()
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//        if !preservingUndoStack {
//            undoManager.removeAllActions()
//        }
        viewportRenderer.renderViewport()
    }
}
