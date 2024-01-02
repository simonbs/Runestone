import Foundation

//struct LineChangeSet {
//    private(set) var insertedLineIDs: Set<LineID>
//    private(set) var removedLineIDs: Set<LineID>
//    private(set) var editedLineIDs: Set<LineID>
//
//    init() {
//        insertedLineIDs = []
//        removedLineIDs = []
//        editedLineIDs = []
//    }
//
//    private init(
//        insertedLineIDs: Set<LineID>,
//        removedLineIDs: Set<LineID>,
//        editedLineIDs: Set<LineID>
//    ) {
//        self.insertedLineIDs = insertedLineIDs
//        self.removedLineIDs = removedLineIDs
//        self.editedLineIDs = editedLineIDs
//    }
//
//    mutating func markLineInserted(_ line: some Line) {
//        removedLineIDs.remove(line.id)
//        editedLineIDs.remove(line.id)
//        insertedLineIDs.insert(line.id)
//    }
//
//    mutating func markLineRemoved(_ line: some Line) {
//        insertedLineIDs.remove(line.id)
//        editedLineIDs.remove(line.id)
//        removedLineIDs.insert(line.id)
//    }
//
//    mutating func markLineEdited(_ line: some Line) {
//        if !insertedLineIDs.contains(line.id) && !removedLineIDs.contains(line.id) {
//            editedLineIDs.insert(line.id)
//        }
//    }
//
//    func union(_ changeSet: LineChangeSet) -> LineChangeSet {
//        LineChangeSet(
//            insertedLineIDs: Set(insertedLineIDs).union(changeSet.insertedLineIDs),
//            removedLineIDs: Set(removedLineIDs).union(changeSet.removedLineIDs),
//            editedLineIDs: Set(editedLineIDs).union(changeSet.editedLineIDs)
//        )
//    }
//}
//
//extension LineChangeSet: CustomDebugStringConvertible {
//    var debugDescription: String {
//        "[LineChangeSet"
//        + " insertedLineIDs=\(insertedLineIDs)"
//        + " removedLineIDs=\(removedLineIDs)"
//        + " editedLineIDs=\(editedLineIDs)"
//        + "]"
//    }
//}

struct LineChangeSet<LineType: Line> {
    private(set) var insertedLines: Set<LineType>
    private(set) var removedLines: Set<LineType>
    private(set) var editedLines: Set<LineType>

    init() {
        insertedLines = []
        removedLines = []
        editedLines = []
    }

    private init(
        insertedLines: Set<LineType>,
        removedLines: Set<LineType>,
        editedLines: Set<LineType>
    ) {
        self.insertedLines = insertedLines
        self.removedLines = removedLines
        self.editedLines = editedLines
    }

    mutating func markLineInserted(_ line: LineType) {
        removedLines.remove(line)
        editedLines.remove(line)
        insertedLines.insert(line)
    }

    mutating func markLineRemoved(_ line: LineType) {
        insertedLines.remove(line)
        editedLines.remove(line)
        removedLines.insert(line)
    }

    mutating func markLineEdited(_ line: LineType) {
        if !insertedLines.contains(line) && !removedLines.contains(line) {
            editedLines.insert(line)
        }
    }

    func union(_ changeSet: LineChangeSet<LineType>) -> LineChangeSet<LineType> {
        LineChangeSet(
            insertedLines: Set(insertedLines).union(changeSet.insertedLines),
            removedLines: Set(removedLines).union(changeSet.removedLines),
            editedLines: Set(editedLines).union(changeSet.editedLines)
        )
    }
}

