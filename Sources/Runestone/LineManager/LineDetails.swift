import Foundation

final class LineDetails {
    let startLocation: Int
    let totalLength: Int
    let position: LinePosition

    init(startLocation: Int, totalLength: Int, position: LinePosition) {
        self.startLocation = startLocation
        self.totalLength = totalLength
        self.position = position
    }
}

extension LineDetails: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[LinePosition startLocation=\(startLocation) totalLength=\(totalLength) position=\(position)]"
    }
}
