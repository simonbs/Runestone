import RunestoneEngine

typealias DocumentLineNodeID = RunestoneEngine.DocumentLineNodeID
typealias DocumentLineTree = RunestoneEngine.DocumentLineTree
typealias DocumentLineNode = RunestoneEngine.DocumentLineNode
typealias DocumentLineNodeData = RunestoneEngine.DocumentLineNodeData
typealias LineManager = RunestoneEngine.LineManager
typealias LineChangeSet = RunestoneEngine.LineChangeSet
typealias LinePosition = RunestoneEngine.LinePosition

extension LinePosition {
    convenience init(_ point: TreeSitterTextPoint) {
        let row = Int(point.row)
        let column = Int(point.column / 2)
        self.init(row: row, column: column)
    }
}
