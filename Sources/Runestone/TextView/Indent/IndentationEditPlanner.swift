import Foundation

struct IndentationLine: Equatable {
    let range: NSRange
    let text: String
}

struct IndentationEdit: Equatable {
    let replacementRange: NSRange
    let replacementText: String
    let selectedRange: NSRange?
}

/// Plans indentation mutations without applying them through a platform text-input system.
enum IndentationEditPlanner {
    static func shiftLeft(lines: [IndentationLine], selectedRange: NSRange,
                          indentString: String) -> IndentationEdit? {
        guard let originalRange = range(surrounding: lines) else {
            return nil
        }
        var replacementText = ""
        var newSelectedRange = selectedRange
        let characterIndentLength = indentString.count
        let utf16IndentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            guard line.text.hasPrefix(indentString) else {
                replacementText += line.text
                continue
            }
            let contentStart = line.text.index(line.text.startIndex, offsetBy: characterIndentLength)
            replacementText += line.text[contentStart...]
            if lineIndex == 0 {
                let preferredLocation = newSelectedRange.location - utf16IndentLength
                let newLocation = max(preferredLocation, originalRange.location)
                newSelectedRange.location = newLocation
                if newLocation > preferredLocation {
                    newSelectedRange.length = max(newSelectedRange.length - (newLocation - preferredLocation), 0)
                }
            } else {
                newSelectedRange.length -= utf16IndentLength
            }
        }
        return IndentationEdit(replacementRange: originalRange, replacementText: replacementText,
                               selectedRange: newSelectedRange)
    }

    static func shiftRight(lines: [IndentationLine], selectedRange: NSRange,
                           indentString: String) -> IndentationEdit? {
        guard let originalRange = range(surrounding: lines) else {
            return nil
        }
        var replacementText = ""
        var newSelectedRange = selectedRange
        let indentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            replacementText += indentString + line.text
            if lineIndex == 0 {
                newSelectedRange.location += indentLength
            } else {
                newSelectedRange.length += indentLength
            }
        }
        return IndentationEdit(replacementRange: originalRange, replacementText: replacementText,
                               selectedRange: newSelectedRange)
    }

    static func insertLineBreak(in range: NSRange, symbol: String, indentString: String,
                                previousIndentString: String? = nil) -> IndentationEdit {
        guard let previousIndentString else {
            return IndentationEdit(replacementRange: range, replacementText: symbol + indentString, selectedRange: nil)
        }
        let firstLineText = symbol + indentString
        return IndentationEdit(replacementRange: range,
                               replacementText: firstLineText + symbol + previousIndentString,
                               selectedRange: NSRange(location: range.location + firstLineText.utf16.count, length: 0))
    }

    static func indentRange(inFrontOf location: Int, lineLocation: Int,
                            currentIndentLength: Int, tabLength: Int) -> NSRange? {
        let localLocation = location - lineLocation
        guard tabLength > 0, localLocation >= tabLength,
              localLocation <= currentIndentLength, localLocation % tabLength == 0 else {
            return nil
        }
        return NSRange(location: location - tabLength, length: tabLength)
    }
}

private extension IndentationEditPlanner {
    static func range(surrounding lines: [IndentationLine]) -> NSRange? {
        guard let firstLine = lines.first, let lastLine = lines.last else {
            return nil
        }
        return NSRange(location: firstLine.range.location, length: lastLine.range.upperBound - firstLine.range.location)
    }
}
