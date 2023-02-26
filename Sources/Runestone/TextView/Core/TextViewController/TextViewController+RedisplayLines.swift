import CoreGraphics

extension TextViewController {
    func invalidateLines() {
        for lineController in lineControllerStorage {
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = indentController.tabWidth
            lineController.kern = kern
            lineController.lineBreakMode = lineBreakMode
            lineController.invalidateSyntaxHighlighting()
        }
    }

    func redisplayVisibleLines() {
        // Ensure we have the correct set of visible lines.
        lineFragmentLayoutManager.setNeedsLayout()
        lineFragmentLayoutManager.layoutIfNeeded()
        // Force a preparation of the lines synchronously.
        redisplayLines(withIDs: lineFragmentLayoutManager.visibleLineIDs)
        setNeedsDisplayOnLines()
        // Then force a relayout of the lines.
        lineFragmentLayoutManager.setNeedsLayout()
        lineFragmentLayoutManager.layoutIfNeeded()
    }

    func redisplayLines(withIDs lineIDs: Set<LineNodeID>) {
        for lineID in lineIDs {
            if let lineController = lineControllerStorage[lineID] {
                lineController.invalidateString()
                lineController.invalidateTypesetting()
                lineController.invalidateSyntaxHighlighting()
                // Only display the line if it's currently visible on the screen. Otherwise it's enough to invalidate it and redisplay it later.
                if lineFragmentLayoutManager.visibleLineIDs.contains(lineID) {
                    let lineYPosition = lineController.line.yPosition
                    let lineLocalViewport = CGRect(x: 0, y: lineYPosition, width: viewport.width, height: viewport.maxY - lineYPosition)
                    lineController.prepareToDisplayString(toYPosition: lineLocalViewport.maxY, syntaxHighlightAsynchronously: false)
                }
            }
        }
    }

    func setNeedsDisplayOnLines() {
        for lineController in lineControllerStorage {
            lineController.setNeedsDisplayOnLineFragmentViews()
        }
    }
}
