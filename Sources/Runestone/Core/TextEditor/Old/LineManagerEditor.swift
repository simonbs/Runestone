import Foundation

struct LineManagerEditor<LineManagerType: LineManaging> {
    let lineManager: LineManagerType

    func replaceText(
        in range: NSRange,
        with newString: String,
        updatingModelUsing updateModel: () -> Void
    ) -> LineManagerEdit<LineManagerType.LineType> {
        let nsNewString = newString as NSString
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        updateModel()
        let removalLineChangeSet = lineManager.removeText(in: range)
        let insertionLineChangeSet = lineManager.insertText(nsNewString, at: range.location)
        let lineChangeSet = removalLineChangeSet.union(insertionLineChangeSet)
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + nsNewString.length)!
        return LineManagerEdit(
            oldEndLinePosition: oldEndLinePosition,
            startLinePosition: startLinePosition,
            newEndLinePosition: newEndLinePosition,
            lineChangeSet: lineChangeSet
        )
    }
}
