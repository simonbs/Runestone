import Foundation

final class LineChangeSet {
    private(set) var insertedLines: Set<LineNode> = []
    private(set) var removedLines: Set<LineNode> = []
    private(set) var editedLines: Set<LineNode> = []

    init() {}

    func markLineInserted(_ line: LineNode) {
        removedLines.remove(line)
        editedLines.remove(line)
        insertedLines.insert(line)
    }

    func markLineRemoved(_ line: LineNode) {
        insertedLines.remove(line)
        editedLines.remove(line)
        removedLines.insert(line)
    }

    func markLineEdited(_ line: LineNode) {
        if !insertedLines.contains(line) && !removedLines.contains(line) {
            editedLines.insert(line)
        }
    }

    func formUnion(with otherChangeSet: LineChangeSet) {
        insertedLines.formUnion(otherChangeSet.insertedLines)
        removedLines.formUnion(otherChangeSet.removedLines)
        editedLines.formUnion(otherChangeSet.editedLines)
    }
}

extension LineChangeSet: CustomDebugStringConvertible {
    var debugDescription: String {
        "[LineChangeSet insertedLines=\(insertedLines) removedLines=\(removedLines) editedLines=\(editedLines)]"
    }
}
