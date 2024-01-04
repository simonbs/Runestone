import Foundation

struct VisibleLine<LineType: Line> {
    let line: LineType
    let lineFragments: [LineType.LineFragmentType]
}
