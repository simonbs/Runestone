import Foundation

enum HorizontalTextMovement {
    static func location(from location: Int, offset: Int, stringView: StringView, lineManager: LineManager) -> Int {
        let naiveNewLocation = lineManager.visibleLocation(location + offset, movingForward: offset > 0)
        guard naiveNewLocation >= 0 && naiveNewLocation <= stringView.string.length else {
            return location
        }
        guard naiveNewLocation > 0 && naiveNewLocation < stringView.string.length else {
            return naiveNewLocation
        }
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: naiveNewLocation)
        guard naiveNewLocation > range.location && naiveNewLocation < range.location + range.length else {
            return naiveNewLocation
        }
        if offset < 0 {
            return lineManager.visibleLocation(location - range.length, movingForward: false)
        } else {
            return lineManager.visibleLocation(location + range.length, movingForward: true)
        }
    }
}
