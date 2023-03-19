import Foundation

struct LineManagerEditor {
    let lineManager: LineManager

    func replaceText(
        in range: NSRange,
        with newString: String,
        updatingModelUsing updateModel: () -> Void
    ) -> LineManagerEdit {
        let nsNewString = newString as NSString
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        updateModel()
        let lineChangeSet = LineChangeSet()
        let lineChangeSetFromRemovingCharacters = lineManager.removeCharacters(in: range)
        lineChangeSet.formUnion(with: lineChangeSetFromRemovingCharacters)
        let lineChangeSetFromInsertingCharacters = lineManager.insert(nsNewString, at: range.location)
        lineChangeSet.formUnion(with: lineChangeSetFromInsertingCharacters)
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
