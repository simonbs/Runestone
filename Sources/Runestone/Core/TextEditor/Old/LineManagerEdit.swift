import Foundation

struct LineManagerEdit<LineType: Line> {
    let oldEndLinePosition: LinePosition
    let startLinePosition: LinePosition
    let newEndLinePosition: LinePosition
    let lineChangeSet: LineChangeSet<LineType>
}
