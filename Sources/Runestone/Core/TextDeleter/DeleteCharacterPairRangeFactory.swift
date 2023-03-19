import Combine
import Foundation

final class DeleteCharacterPairRangeFactory {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let characterPairService: CharacterPairService

    init(stringView: CurrentValueSubject<StringView, Never>, characterPairService: CharacterPairService) {
        self.stringView = stringView
        self.characterPairService = characterPairService
    }

    func rangeIncludingTrailingCharacterPairComponent(behind range: NSRange) -> NSRange? {
        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
        guard characterPairService.trailingComponentDeletionMode == .immediatelyFollowingLeadingComponent else {
            return nil
        }
        let stringToDelete = stringView.value.substring(in: range)
        guard let characterPair = characterPairService.characterPairs.first(where: { $0.leading == stringToDelete }) else {
            return nil
        }
        let trailingComponentLength = characterPair.trailing.utf16.count
        let trailingComponentRange = NSRange(location: range.upperBound, length: trailingComponentLength)
        guard stringView.value.substring(in: trailingComponentRange) == characterPair.trailing else {
            return nil
        }
        let deleteLength = trailingComponentRange.upperBound - range.lowerBound
        return NSRange(location: range.lowerBound, length: deleteLength)
    }
}
