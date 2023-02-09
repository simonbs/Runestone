import Foundation

final class NavigationService {
    var stringView: StringView
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                lineNavigationLocationService.lineManager = lineManager
            }
        }
    }

    private let lineControllerStorage: LineControllerStorage
    private var stringTokenizer: StringTokenizer {
        StringTokenizer(stringView: stringView, lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }
    private var characterNavigationLocationService: CharacterNavigationLocationFactory {
        CharacterNavigationLocationFactory(stringView: stringView)
    }
    private var wordNavigationLocationService: WordNavigationLocationFactory {
        WordNavigationLocationFactory(stringTokenizer: stringTokenizer)
    }
    private var lineNavigationLocationService: StatefulLineNavigationLocationFactory

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.lineNavigationLocationService = StatefulLineNavigationLocationFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    func location(movingFrom location: Int, byCharacterCount offset: Int, inDirection direction: TextDirection) -> Int {
        characterNavigationLocationService.location(movingFrom: location, byCharacterCount: offset, inDirection: direction)
    }

    func location(movingFrom location: Int, byLineCount offset: Int, inDirection direction: TextDirection) -> Int {
        lineNavigationLocationService.location(movingFrom: location, byLineCount: offset, inDirection: direction)
    }

    func location(movingFrom sourceLocation: Int, byWordCount offset: Int, inDirection direction: TextDirection) -> Int {
        wordNavigationLocationService.location(movingFrom: sourceLocation, byWordCount: offset, inDirection: direction)
    }

    func location(moving sourceLocation: Int, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> Int {
        stringTokenizer.location(from: sourceLocation, toBoundary: boundary, inDirection: direction) ?? sourceLocation
    }

    func resetPreviousLineNavigationOperation() {
        lineNavigationLocationService.reset()
    }
}
