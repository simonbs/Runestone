import Foundation

public final class LineChangeSet {
    public private(set) var insertedLines: Set<DocumentLineNode> = []
    public private(set) var removedLines: Set<DocumentLineNode> = []
    public private(set) var editedLines: Set<DocumentLineNode> = []

    public init() {}

    public func markLineInserted(_ line: DocumentLineNode) {
        removedLines.remove(line)
        editedLines.remove(line)
        insertedLines.insert(line)
    }

    public func markLineRemoved(_ line: DocumentLineNode) {
        insertedLines.remove(line)
        editedLines.remove(line)
        removedLines.insert(line)
    }

    public func markLineEdited(_ line: DocumentLineNode) {
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
