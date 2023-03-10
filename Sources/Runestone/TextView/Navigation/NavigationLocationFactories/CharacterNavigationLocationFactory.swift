import Combine

struct CharacterNavigationLocationFactory {
    private let stringView: CurrentValueSubject<StringView, Never>

    init(stringView: CurrentValueSubject<StringView, Never>) {
        self.stringView = stringView
    }

    func location(movingFrom sourceLocation: Int, byCharacterCount offset: Int = 1, inDirection direction: TextDirection) -> Int {
        let naiveNewLocation: Int
        switch direction {
        case .forward:
            naiveNewLocation = sourceLocation + offset
        case .backward:
            naiveNewLocation = sourceLocation - offset
        }
        guard naiveNewLocation >= 0 && naiveNewLocation <= stringView.value.string.length else {
            return sourceLocation
        }
        guard naiveNewLocation > 0 && naiveNewLocation < stringView.value.string.length else {
            return naiveNewLocation
        }
        let range = stringView.value.string.customRangeOfComposedCharacterSequence(at: naiveNewLocation)
        guard naiveNewLocation > range.location && naiveNewLocation < range.location + range.length else {
            return naiveNewLocation
        }
        switch direction {
        case .forward:
            return sourceLocation + range.length
        case .backward:
            return sourceLocation - range.length
        }
    }
}
