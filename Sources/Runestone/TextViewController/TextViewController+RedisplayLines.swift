import CoreGraphics

extension TextViewController {
//    func invalidateLines() {
//        for lineController in lineControllerStorage {
//            lineController.invalidateSyntaxHighlighting()
//        }
//    }
//
//    func redisplayVisibleLines() {
//        // Ensure we have the correct set of visible lines.
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//        // Force a preparation of the lines synchronously.
//        redisplayLines(withIDs: lineFragmentLayouter.visibleLineIDs)
//        setNeedsDisplayOnLines()
//        // Then force a relayout of the lines.
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//    }
//
//    func redisplayLines(withIDs lineIDs: Set<LineNodeID>) {
//        for lineID in lineIDs {
//            guard let lineController = lineControllerStorage[lineID] else {
//                continue
//            }
//            lineController.invalidateString()
//            lineController.invalidateTypesetting()
//            lineController.invalidateSyntaxHighlighting()
//            // Only display the line if it's currently visible on the screen. Otherwise it's enough to invalidate it and redisplay it later.
//            guard lineFragmentLayouter.visibleLineIDs.contains(lineID) else {
//                continue
//            }
//            let lineYPosition = lineController.line.yPosition
//            let lineLocalMaxY = lineYPosition + (textContainer.viewport.value.maxY - lineYPosition)
//            lineController.prepareToDisplayString(to: .yPosition(lineLocalMaxY), syntaxHighlightAsynchronously: false)
//        }
//    }
//
//    func setNeedsDisplayOnLines() {
//        for lineController in lineControllerStorage {
//            lineController.setNeedsDisplayOnLineFragmentViews()
//        }
//    }
}
