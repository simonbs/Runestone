import Foundation

public final class LineChangeSet {
    public private(set) var insertedLines: Set<LineNode> = []
    public private(set) var removedLines: Set<LineNode> = []
    public private(set) var editedLines: Set<LineNode> = []

    public init() {}

    public func markLineInserted(_ line: LineNode) {
        removedLines.remove(line)
        editedLines.remove(line)
        insertedLines.insert(line)
    }

    public func markLineRemoved(_ line: LineNode) {
        insertedLines.remove(line)
        editedLines.remove(line)
        removedLines.insert(line)
    }

    public func markLineEdited(_ line: LineNode) {
        if !insertedLines.contains(line) && !removedLines.contains(line) {
            editedLines.insert(line)
        }
    }

    public func union(with otherChangeSet: LineChangeSet) {
        insertedLines.formUnion(otherChangeSet.insertedLines)
        removedLines.formUnion(otherChangeSet.removedLines)
        editedLines.formUnion(otherChangeSet.editedLines)
    }
}

extension LineChangeSet: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[LineChangeSet insertedLines=\(insertedLines) removedLines=\(removedLines) editedLines=\(editedLines)]"
    }
}
