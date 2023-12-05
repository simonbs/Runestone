import Foundation

final class LineChangeSet {
    private(set) var insertedLineIDs: Set<UUID> = []
    private(set) var removedLineIDs: Set<UUID> = []
    private(set) var editedLineIDs: Set<UUID> = []

    init() {}

    func markLineInserted(_ line: some Line) {
        removedLineIDs.remove(line.id)
        editedLineIDs.remove(line.id)
        insertedLineIDs.insert(line.id)
    }

    func markLineRemoved(_ line: some Line) {
        insertedLineIDs.remove(line.id)
        editedLineIDs.remove(line.id)
        removedLineIDs.insert(line.id)
    }

    func markLineEdited(_ line: some Line) {
        if !insertedLineIDs.contains(line.id) && !removedLineIDs.contains(line.id) {
            editedLineIDs.insert(line.id)
        }
    }

    func formUnion(with otherChangeSet: LineChangeSet) {
        insertedLineIDs.formUnion(otherChangeSet.insertedLineIDs)
        removedLineIDs.formUnion(otherChangeSet.removedLineIDs)
        editedLineIDs.formUnion(otherChangeSet.editedLineIDs)
    }
}

extension LineChangeSet: CustomDebugStringConvertible {
    var debugDescription: String {
        "[LineChangeSet"
        + " insertedLineIDs=\(insertedLineIDs)"
        + " removedLineIDs=\(removedLineIDs)"
        + " editedLineIDs=\(editedLineIDs)"
        + "]"
    }
}
