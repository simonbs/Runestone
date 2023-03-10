import Combine
import Foundation

final class SelectedRangeService {
    private(set) var selectedRange = NSRange(location: 0, length: 0)

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>

    init(stringView: CurrentValueSubject<StringView, Never>, lineManager: CurrentValueSubject<LineManager, Never>) {
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func moveCaret(to location: Int) {
        let safeLocation = min(max(location, 0), stringView.value.string.length)
        selectedRange = NSRange(location: safeLocation, length: 0)
    }

    func moveCaret(to linePosition: LinePosition) {
        if linePosition.row < lineManager.value.lineCount {
            let line = lineManager.value.line(atRow: linePosition.row)
            let location = line.location + min(linePosition.column, line.data.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = NSRange(location: 0, length: 0)
        }
    }

    func selectRange(_ range: NSRange) {
        selectedRange = range.capped(to: stringView.value.string.length)
    }
}
