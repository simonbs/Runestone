import Foundation

struct LineManagerTextReplacer<
    LineManagerType: LineManaging,
    LineChangeSetHandlingType: LineChangeSetHandling
>: TextReplacing {
    let lineManager: LineManagerType
    let changeSetHandler: LineChangeSetHandlingType

    func replaceText(in range: NSRange, with newText: String) {
        let removalChangeSet = lineManager.removeText(in: range)
        let insertionChangeSet = lineManager.insertText(newText as NSString, at: range.location)
        let changeSet = removalChangeSet.union(insertionChangeSet)
        changeSetHandler.handle(changeSet)
    }
}
