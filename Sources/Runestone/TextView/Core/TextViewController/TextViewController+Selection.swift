import Foundation

extension TextViewController {
    func safeSelectionRange(from range: NSRange) -> NSRange {
        let stringLength = stringView.string.length
        let cappedLocation = min(max(range.location, 0), stringLength)
        let cappedLength = min(max(range.length, 0), stringLength - cappedLocation)
        return NSRange(location: cappedLocation, length: cappedLength)
    }
}
