import Foundation

extension TextViewController {
    func performFullLayout() {
        invalidateLines()
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    func performFullLayoutIfNeeded() {
        if hasPendingFullLayout && textView.window != nil {
            hasPendingFullLayout = false
            performFullLayout()
        }
    }

    func layoutIfNeeded() {
        layoutManager.layoutIfNeeded()
        layoutManager.layoutLineSelectionIfNeeded()
        layoutPageGuideIfNeeded()
    }

    func invalidateLines() {
        for lineController in lineControllerStorage {
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = indentController.tabWidth
            lineController.kern = kern
            lineController.lineBreakMode = lineBreakMode
            lineController.invalidateSyntaxHighlighting()
        }
    }

    func applyLineChangesToLayoutManager(_ lineChangeSet: LineChangeSet) {
        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            contentSizeService.invalidateContentSize()
            for removedLine in lineChangeSet.removedLines {
                lineControllerStorage.removeLineController(withID: removedLine.id)
                contentSizeService.removeLine(withID: removedLine.id)
            }
        }
        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
        layoutManager.redisplayLines(withIDs: editedLineIDs)
        if didAddOrRemoveLines {
            gutterWidthService.invalidateLineNumberWidth()
        }
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    func layoutPageGuideIfNeeded() {
        guard showPageGuide else {
            return
        }
        // The width extension is used to make the page guide look "attached" to the right hand side, even when the scroll view bouncing on the right side.
        let maxContentOffsetX = contentSizeService.contentWidth - viewport.width
        let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
        let xPosition = gutterWidthService.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
        let width = max(contentSizeService.contentWidth - xPosition + widthExtension, 0)
        let origin = CGPoint(x: xPosition, y: viewport.minY)
        let pageGuideSize = CGSize(width: width, height: viewport.height)
        pageGuideController.guideView.frame = CGRect(origin: origin, size: pageGuideSize)
    }
}
