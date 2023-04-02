import Combine

final class TextLocationConverter {
    private let lineManager: CurrentValueSubject<LineManager, Never>

    init(lineManager: CurrentValueSubject<LineManager, Never>) {
        self.lineManager = lineManager
    }

    func textLocation(at location: Int) -> TextLocation? {
        if let linePosition = lineManager.value.linePosition(at: location) {
            return TextLocation(linePosition)
        } else {
            return nil
        }
    }

    func location(at textLocation: TextLocation) -> Int? {
        let lineIndex = textLocation.lineNumber
        guard lineIndex >= 0 && lineIndex < lineManager.value.lineCount else {
            return nil
        }
        let line = lineManager.value.line(atRow: lineIndex)
        guard textLocation.column >= 0 && textLocation.column <= line.data.totalLength else {
            return nil
        }
        return line.location + textLocation.column
    }
}
