import Foundation

struct TypesettingInvalidatingLineChangeSetHandler: LineChangeSetHandling {
    func handle<LineType: Line>(_ lineChangeSet: LineChangeSet<LineType>) {
        for line in lineChangeSet.editedLines {
            line.invalidateTypesetText()
        }
    }
}
