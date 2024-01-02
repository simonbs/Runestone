import Foundation

protocol LineManaging {
    associatedtype LineType: Line
    var lineCount: Int { get }
    func insertText(_ text: NSString, at location: Int) -> LineChangeSet<LineType>
    func removeText(in range: NSRange) -> LineChangeSet<LineType>
    func line(containingCharacterAt location: Int) -> LineType?
    func line(atYOffset yOffset: CGFloat) -> LineType?
    func lines(in range: NSRange) -> [LineType]
    func firstAndLastLine(in range: NSRange) -> (LineType, LineType)?
    func linePosition(at location: Int) -> LinePosition?
    func makeLineIterator() -> AnyIterator<LineType>
    subscript(row: Int) -> LineType { get }
}

extension LineManaging {
    func linePosition(at location: Int) -> LinePosition? {
        guard let line = line(containingCharacterAt: location) else {
            return nil
        }
        let column = location - line.location
        return LinePosition(row: line.index, column: column)
    }

    func lines(in range: NSRange) -> [LineType] {
        guard let firstLine = line(containingCharacterAt: range.location) else {
            return []
        }
        var lines: [LineType] = [firstLine]
        guard range.length > 0 else {
            return lines
        }
        guard let lastLine = line(containingCharacterAt: range.location + range.length) else {
            return lines
        }
        guard lastLine != firstLine else {
            return lines
        }
        let startLineIndex = firstLine.index + 1 // Skip the first line since we already have it.
        let endLineIndex = lastLine.index - 1 // Skip the last line since we already have it.
        if startLineIndex <= endLineIndex {
            lines += (startLineIndex ... endLineIndex).map { self[$0] }
        }
        lines.append(lastLine)
        return lines
    }

    func firstAndLastLine(in range: NSRange) -> (LineType, LineType)? {
        if range.length == 0 {
            if let line = line(containingCharacterAt: range.lowerBound) {
                return (line, line)
            } else {
                return nil
            }
        } else if let startLine = line(containingCharacterAt: range.lowerBound),
                  let endLine = line(containingCharacterAt: range.upperBound) {
            return (startLine, endLine)
        } else {
            return nil
        }
    }
}
