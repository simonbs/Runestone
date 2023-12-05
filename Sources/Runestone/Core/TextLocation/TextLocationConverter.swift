import Combine

final class TextLocationConverter<LineManagerType: LineManaging> {
    private let lineManager: LineManagerType

    init(lineManager: LineManagerType) {
        self.lineManager = lineManager
    }

    func textLocation(at location: Int) -> TextLocation? {
        if let linePosition = lineManager.linePosition(at: location) {
            return TextLocation(linePosition)
        } else {
            return nil
        }
    }

    func location(at textLocation: TextLocation) -> Int? {
        let lineIndex = textLocation.lineNumber
        guard lineIndex >= 0 && lineIndex < lineManager.lineCount else {
            return nil
        }
        let line = lineManager[lineIndex]
        guard textLocation.column >= 0 && textLocation.column <= line.totalLength else {
            return nil
        }
        return line.location + textLocation.column
    }
}
